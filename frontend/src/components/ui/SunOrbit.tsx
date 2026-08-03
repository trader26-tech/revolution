import { memo, useMemo, useState } from "react";
import type { CSSProperties } from "react";
import type { Cycle, Subscription } from "@/lib/types";
import { monthly } from "@/lib/money";
import { BrandLogo } from "./BrandLogo";
import "./sun-orbit.css";

interface Props {
  subs: Subscription[];
  size?: number;
  /** Tapping a revealed moon opens that subscription. */
  onSelect?: (id: string) => void;
}

/** HARD CAP on rendered moons. The orbit is a visual, not a data table: it
 *  shows the biggest movers. Whether the user has 5 records or 5000, at most
 *  this many animated elements exist — the orbit's cost is CONSTANT. */
const MAX_MOONS = 16;

/** The three billing cycles, mapped to rings from the inside out:
 *  weekly (fastest, closest) → monthly → yearly (slowest, farthest). */
const RINGS: { cycle: Cycle; rFactor: number; dur: number }[] = [
  { cycle: "weekly", rFactor: 0.22, dur: 26 },
  { cycle: "monthly", rFactor: 0.31, dur: 40 },
  { cycle: "yearly", rFactor: 0.4, dur: 58 },
];

/** The home hero: a warm glowing sun ringed by three orbits — one per billing
 *  cycle — with subscriptions riding their ring as silver moons (income wears
 *  a translucent ring). Tapping the sun flips the moons to their brand logos.
 *
 *  PERFORMANCE CONTRACT (the whole point of this component's design):
 *  - Zero JavaScript per animation frame. Every motion — orbiting, staying
 *    upright, the flip, the entrance, the sun pulse — is a CSS transform
 *    animation, which runs entirely on the compositor thread.
 *  - The orbit trick: each moon sits in a rotating 0×0 wrapper; an inner
 *    element counter-rotates with the SAME duration and delay, so both share
 *    one animation clock and the moon stays upright with zero drift.
 *  - Phase offset is a negative animation-delay — free.
 *  - At most MAX_MOONS moons render, ever. 1000 records cost what 16 cost. */
export const SunOrbit = memo(function SunOrbit({
  subs,
  size = 300,
  onSelect,
}: Props) {
  const [revealed, setRevealed] = useState(false);

  // Pick the moons to show: the biggest amounts win (they're what the user
  // cares about seeing), then group them by cycle for their rings.
  const byCycle = useMemo(() => {
    const shown =
      subs.length <= MAX_MOONS
        ? subs
        : [...subs]
            .sort((a, b) => monthly(b.amount, b.cycle) - monthly(a.amount, a.cycle))
            .slice(0, MAX_MOONS);
    const map: Record<Cycle, Subscription[]> = {
      weekly: [],
      monthly: [],
      yearly: [],
    };
    for (const s of shown) map[s.cycle].push(s);
    return map;
  }, [subs]);

  // Cost → size scale, computed once per data change (never per frame).
  const [minCost, maxCost] = useMemo(() => {
    if (!subs.length) return [0, 1];
    let lo = Infinity;
    let hi = -Infinity;
    for (const s of subs) {
      const c = monthly(s.amount, s.cycle);
      if (c < lo) lo = c;
      if (c > hi) hi = c;
    }
    return [lo, hi];
  }, [subs]);

  const costSize = (s: Subscription) => {
    const floor = size * 0.05;
    const ceil = size * 0.1;
    const c = monthly(s.amount, s.cycle);
    const t = maxCost === minCost ? 0.5 : (c - minCost) / (maxCost - minCost);
    return floor + (ceil - floor) * t;
  };

  const hasSubs = subs.length > 0;
  const EDGE_PAD = size * 0.01;

  return (
    <div className="sun-orbit" style={{ width: size, height: size }}>
      {/* three orbit guide rings */}
      {RINGS.map((ring) => (
        <div
          key={ring.cycle}
          className="sun-orbit__ring"
          style={{
            width: ring.rFactor * 2 * size,
            height: ring.rFactor * 2 * size,
          }}
          aria-hidden
        />
      ))}

      {/* moons — pure CSS orbits, capped count */}
      {RINGS.map((ring) => {
        const items = byCycle[ring.cycle];
        const r = ring.rFactor * size;
        const n = items.length;
        if (!n) return null;

        // no-overlap: cap diameter to the arc between evenly spaced moons
        const gap = (2 * Math.PI * r) / n;
        const maxByGap = gap * 0.62;
        // never off-screen: the moon's edge stays inside the box
        const maxByEdge = (size / 2 - r - EDGE_PAD) * 2;

        return items.map((sub, i) => {
          const d = Math.max(
            size * 0.036,
            Math.min(costSize(sub), maxByGap, maxByEdge)
          );
          const phase = i / n;
          const vars = {
            "--dur": `${ring.dur}s`,
            // negative delay starts the shared clock mid-cycle = phase offset
            "--ph": `${(-phase * ring.dur).toFixed(3)}s`,
            "--r": `${r}px`,
          } as CSSProperties;
          return (
            <div key={sub.id} className="sun-orbit__orbiter" style={vars} aria-hidden={!revealed}>
              <button
                className={"sun-orbit__moon" + (revealed ? " is-revealed" : "")}
                style={{ width: d, height: d }}
                onClick={(e) => {
                  e.stopPropagation();
                  if (revealed) onSelect?.(sub.id);
                }}
                tabIndex={revealed ? 0 : -1}
                title={revealed ? sub.name : undefined}
                aria-label={revealed ? `Open ${sub.name}` : undefined}
              >
                {/* counter-rotates on the same clock → always upright */}
                <div className="sun-orbit__upright">
                  {/* one-shot entrance, staggered */}
                  <div
                    className="sun-orbit__enter"
                    style={{ animationDelay: `${i * 0.05}s` }}
                  >
                    <div
                      className="sun-orbit__flip"
                      style={{ transitionDelay: `${i * 0.06}s` }}
                    >
                      <div className="sun-orbit__face sun-orbit__face--ash">
                        <Moon d={d} income={sub.flow === "income"} />
                      </div>
                      <div className="sun-orbit__face sun-orbit__face--logo">
                        <BrandLogo
                          name={sub.name}
                          brandSlug={sub.brandSlug}
                          mark={sub.mark}
                          fallbackColor={sub.color}
                          size={d}
                          radius={d / 2}
                        />
                      </div>
                    </div>
                  </div>
                </div>
              </button>
            </div>
          );
        });
      })}

      {/* the sun — tap to reveal / hide what each moon is */}
      <button
        className="sun-orbit__sun"
        style={{ width: size * 0.34, height: size * 0.34 }}
        onClick={() => hasSubs && setRevealed((v) => !v)}
        aria-label={revealed ? "Hide subscription names" : "Show what each moon is"}
      >
        <Sun size={size * 0.34} />
      </button>
    </div>
  );
});

/** The glowing orange→pink→magenta star at the centre. CSS pulse, no JS. */
function Sun({ size }: { size: number }) {
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 100 100"
      className="sun-orbit__sun-svg"
      style={{ display: "block", overflow: "visible" }}
      aria-hidden
    >
      <defs>
        <radialGradient id="sun-core" cx="42%" cy="34%" r="72%">
          <stop offset="0%" stopColor="#ffd08a" />
          <stop offset="34%" stopColor="#ff9d3c" />
          <stop offset="64%" stopColor="#ff5a4d" />
          <stop offset="100%" stopColor="#ff1f7a" />
        </radialGradient>
        <radialGradient id="sun-halo" cx="50%" cy="50%" r="50%">
          <stop offset="0%" stopColor="#ff7a3c" stopOpacity="0.55" />
          <stop offset="55%" stopColor="#ff2d78" stopOpacity="0.25" />
          <stop offset="100%" stopColor="#ff2d78" stopOpacity="0" />
        </radialGradient>
      </defs>
      <circle cx="50" cy="50" r="66" fill="url(#sun-halo)" />
      <circle cx="50" cy="50" r="42" fill="url(#sun-core)" />
      <ellipse cx="44" cy="40" rx="26" ry="18" fill="#ffb15a" opacity="0.35" />
      <ellipse cx="58" cy="62" rx="22" ry="14" fill="#ff2d78" opacity="0.3" />
      <circle cx="50" cy="50" r="42" fill="none" stroke="#ffd9a8" strokeWidth="1" opacity="0.4" />
    </svg>
  );
}

/** A plain silver/ash sphere. Income wears a translucent halo ring; expenses
 *  are bare. Differentiation is by shape — no colour to mismatch. */
function Moon({ d, income }: { d: number; income: boolean }) {
  const id = "moon-" + Math.round(d * 10);
  return (
    <svg
      width={d}
      height={d}
      viewBox="-16 -16 132 132"
      style={{ display: "block", overflow: "visible" }}
    >
      <defs>
        <radialGradient id={id} cx="38%" cy="30%" r="82%">
          <stop offset="0%" stopColor="#eceef4" />
          <stop offset="46%" stopColor="#c2c5d1" />
          <stop offset="80%" stopColor="#8f93a4" />
          <stop offset="100%" stopColor="#565a6d" />
        </radialGradient>
        <radialGradient
          id={id + "-band"}
          cx="50"
          cy="50"
          r="68"
          fx="50"
          fy="50"
          gradientUnits="userSpaceOnUse"
        >
          <stop offset="0%" stopColor="#c9cede" stopOpacity="0" />
          <stop offset="80%" stopColor="#c9cede" stopOpacity="0" />
          <stop offset="85%" stopColor="#d7dbec" stopOpacity="0.16" />
          <stop offset="91%" stopColor="#ffffff" stopOpacity="0.34" />
          <stop offset="97%" stopColor="#d7dbec" stopOpacity="0.16" />
          <stop offset="100%" stopColor="#8f93a4" stopOpacity="0" />
        </radialGradient>
      </defs>

      {income && (
        <>
          <circle cx="50" cy="50" r="62" fill="none" stroke="#eef1fb" strokeWidth="13" opacity="0.06" />
          <circle cx="50" cy="50" r="62" fill="none" stroke="#dfe3f2" strokeWidth="11" opacity="0.07" />
          <circle cx="50" cy="50" r="62" fill="none" stroke={`url(#${id}-band)`} strokeWidth="11" />
          <circle cx="50" cy="50" r="62" fill="none" stroke="#ffffff" strokeWidth="1.2" opacity="0.22" />
        </>
      )}

      <circle cx="50" cy="50" r="47" fill={`url(#${id})`} />
      <circle cx="50" cy="50" r="46.4" fill="none" stroke="#ffffff" strokeWidth="1" opacity="0.14" />
    </svg>
  );
}
