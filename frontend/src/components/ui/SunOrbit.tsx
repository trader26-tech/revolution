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

/** The three billing cycles map to bands from the inside out: weekly (fastest,
 *  closest) → monthly → yearly (slowest, farthest). Each band can split into
 *  several concentric sub-rings when it holds too many moons to fit one ring
 *  without overlapping. */
const BANDS: { cycle: Cycle; rInner: number; rOuter: number; baseDur: number }[] = [
  { cycle: "weekly", rInner: 0.19, rOuter: 0.26, baseDur: 26 },
  { cycle: "monthly", rInner: 0.29, rOuter: 0.37, baseDur: 40 },
  { cycle: "yearly", rInner: 0.4, rOuter: 0.48, baseDur: 58 },
];

/** One concrete ring to render: a radius, a set of moons, and a spin duration
 *  + direction. Alternating directions on stacked sub-rings reads as depth. */
interface Ring {
  key: string;
  r: number; // px
  dur: number; // seconds per lap
  dir: 1 | -1;
  items: Subscription[];
}

/** The home hero: a glowing sun with subscriptions orbiting as silver moons.
 *
 *  PERFORMANCE + STABILITY CONTRACT
 *  - ALL subscriptions render — no cap.
 *  - Exactly TWO CSS animations per ring (spin + counter-spin), regardless of
 *    how many moons that ring carries. 1000 moons across a handful of rings is
 *    a handful of compositor animations, not 1000. Everything is a `transform`,
 *    so it runs on the GPU/compositor thread — zero JS per frame.
 *  - Moons keep orbiting even while their logos are revealed: the counter-spin
 *    ring cancels the spin so each logo stays upright *without* freezing.
 *  - FILTER-STABLE: a moon's angle is a pure function of its index in its ring
 *    (i / n). No animation-delay tricks, so changing the filter just re-lays
 *    the static children of a still-running animation — nothing drifts. */
export const SunOrbit = memo(function SunOrbit({
  subs,
  size = 300,
  onSelect,
}: Props) {
  const [revealed, setRevealed] = useState(false);

  // Cost → size scale (computed once per data change, never per frame).
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

  const moonSize = (s: Subscription) => {
    const floor = size * 0.05;
    const ceil = size * 0.092;
    const c = monthly(s.amount, s.cycle);
    const t = maxCost === minCost ? 0.5 : (c - minCost) / (maxCost - minCost);
    return floor + (ceil - floor) * t;
  };

  // Build the concrete rings: group by cycle, then split each cycle's moons
  // across concentric sub-rings so no ring is ever overcrowded.
  const rings = useMemo<Ring[]>(() => {
    const byCycle: Record<Cycle, Subscription[]> = {
      weekly: [],
      monthly: [],
      yearly: [],
    };
    for (const s of subs) byCycle[s.cycle].push(s);

    // a representative moon diameter for spacing maths (the floor size)
    const moonD = size * 0.05;
    const out: Ring[] = [];

    for (const band of BANDS) {
      const items = byCycle[band.cycle];
      if (!items.length) continue;

      // how many moons fit on the innermost ring of this band without touching?
      const rInnerPx = band.rInner * size;
      const perRing = Math.max(4, Math.floor((2 * Math.PI * rInnerPx) / (moonD * 1.5)));
      const subRingCount = Math.ceil(items.length / perRing);

      for (let k = 0; k < subRingCount; k++) {
        // spread sub-rings evenly across the band's radial thickness
        const f =
          subRingCount === 1 ? 0 : k / (subRingCount - 1);
        const r = (band.rInner + (band.rOuter - band.rInner) * f) * size;
        // deal moons round-robin so each sub-ring gets a fair, even share
        const ringItems = items.filter((_, idx) => idx % subRingCount === k);
        out.push({
          key: `${band.cycle}-${k}`,
          r,
          // outer sub-rings a touch slower; alternate direction for depth
          dur: band.baseDur * (1 + k * 0.12),
          dir: k % 2 === 0 ? 1 : -1,
          items: ringItems,
        });
      }
    }
    return out;
  }, [subs, size]);

  const hasSubs = subs.length > 0;
  const EDGE_PAD = size * 0.008;

  return (
    <div className="sun-orbit" style={{ width: size, height: size }}>
      {/* faint guide ring per band (purely decorative, one per cycle) */}
      {BANDS.map((band) => (
        <div
          key={band.cycle}
          className="sun-orbit__guide"
          style={{
            width: band.rInner * 2 * size,
            height: band.rInner * 2 * size,
          }}
          aria-hidden
        />
      ))}

      {/* each ring is ONE spinning group. Two animations per ring total. */}
      {rings.map((ring) => {
        const n = ring.items.length;
        const gap = (2 * Math.PI * ring.r) / n;
        const maxByGap = gap * 0.66;
        const maxByEdge = (size / 2 - ring.r - EDGE_PAD) * 2;

        // spin one way, counter-spin the exact opposite; both same duration
        const spinDir = ring.dir === 1 ? "normal" : "reverse";
        const counterDir = ring.dir === 1 ? "reverse" : "normal";
        const spinVars = {
          "--dur": `${ring.dur}s`,
          "--spin-dir": spinDir,
          "--counter-dir": counterDir,
        } as CSSProperties;

        return (
          <div key={ring.key} className="sun-orbit__spin" style={spinVars}>
            {/* counter-spins on the SAME clock → children stay upright while
                the group keeps orbiting */}
            <div className="sun-orbit__counter" style={spinVars}>
              {ring.items.map((sub, i) => {
                const d = Math.min(moonSize(sub), maxByGap, maxByEdge);
                const angle = (i / n) * 360; // STATIC — filter-stable
                const moonVars = {
                  "--a": `${angle}deg`,
                  "--r": `${ring.r}px`,
                } as CSSProperties;
                return (
                  <button
                    key={sub.id}
                    className={"sun-orbit__moon" + (revealed ? " is-revealed" : "")}
                    style={{ ...moonVars, width: d, height: d } as CSSProperties}
                    onClick={(e) => {
                      e.stopPropagation();
                      if (revealed) onSelect?.(sub.id);
                    }}
                    tabIndex={revealed ? 0 : -1}
                    title={revealed ? sub.name : undefined}
                    aria-label={revealed ? `Open ${sub.name}` : undefined}
                  >
                    <span className="sun-orbit__flip">
                      <span className="sun-orbit__face sun-orbit__face--ash">
                        <Moon d={d} income={sub.flow === "income"} />
                      </span>
                      {/* logo only mounts once revealed — keeps un-revealed
                          orbit as light as possible at high moon counts */}
                      {revealed && (
                        <span className="sun-orbit__face sun-orbit__face--logo">
                          <BrandLogo
                            name={sub.name}
                            brandSlug={sub.brandSlug}
                            mark={sub.mark}
                            fallbackColor={sub.color}
                            size={d}
                            radius={d / 2}
                          />
                        </span>
                      )}
                    </span>
                  </button>
                );
              })}
            </div>
          </div>
        );
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
        {income && (
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
        )}
      </defs>

      {income && (
        <>
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
