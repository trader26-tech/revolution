import { useMemo, useState } from "react";
import type { CSSProperties } from "react";
import { motion } from "framer-motion";
import type { Cycle, Subscription } from "@/lib/types";
import { monthly } from "@/lib/money";
import "./sun-orbit.css";

interface Props {
  subs: Subscription[];
  size?: number;
  /** Tapping a revealed moon opens that subscription. */
  onSelect?: (id: string) => void;
}

/** The three billing cycles, mapped to rings from the inside out:
 *  weekly (fastest, closest) → monthly → yearly (slowest, farthest). */
const RINGS: { cycle: Cycle; rFactor: number; dur: number; dir: 1 | -1 }[] = [
  { cycle: "weekly", rFactor: 0.22, dur: 26, dir: 1 },
  { cycle: "monthly", rFactor: 0.31, dur: 40, dir: -1 },
  { cycle: "yearly", rFactor: 0.4, dur: 58, dir: 1 },
];

/** The home hero: a warm glowing sun ringed by three clean orbits — one per
 *  billing cycle. Each subscription rides *its* cycle's ring as a plain ash
 *  moon, sized by cost. Two guarantees hold no matter the data:
 *   1. moons on a ring never overlap (size capped to the ring's spacing);
 *   2. no moon ever leaves the box (ring radius + moon radius ≤ size/2).
 *  Tapping the sun flips every moon to reveal its brand logo (tap again to
 *  hide). Tapping a *revealed* moon opens that subscription. */
export function SunOrbit({ subs, size = 300, onSelect }: Props) {
  const [revealed, setRevealed] = useState(false);

  // Group subscriptions by billing cycle so each ring carries its own set.
  const byCycle = useMemo(() => {
    const map: Record<Cycle, Subscription[]> = {
      weekly: [],
      monthly: [],
      yearly: [],
    };
    for (const s of subs) map[s.cycle].push(s);
    return map;
  }, [subs]);

  // Cost range for sizing (min → max moon by monthly-normalised amount).
  const [minCost, maxCost] = useMemo(() => {
    if (!subs.length) return [0, 1];
    const c = subs.map((s) => monthly(s.amount, s.cycle));
    return [Math.min(...c), Math.max(...c)];
  }, [subs]);

  /** Cost-driven moon diameter within [floor, ceil]. Continuous, so pricier
   *  subs read as bigger moons. */
  const costSize = (s: Subscription) => {
    const floor = size * 0.05;
    const ceil = size * 0.1;
    const c = monthly(s.amount, s.cycle);
    const t = maxCost === minCost ? 0.5 : (c - minCost) / (maxCost - minCost);
    return floor + (ceil - floor) * t;
  };

  const hasSubs = subs.length > 0;

  // Hard edge budget: a moon centred on ring radius r must keep its whole
  // circle inside the size×size box → r + d/2 ≤ size/2 − EDGE_PAD.
  const EDGE_PAD = size * 0.01;

  return (
    <div className="sun-orbit" style={{ width: size, height: size }}>
      {/* three clean orbit guide rings — brighten while revealed */}
      {RINGS.map((ring, i) => (
        <div
          key={ring.cycle}
          className={"sun-orbit__ring" + (revealed ? " is-open" : "")}
          style={{
            width: ring.rFactor * 2 * size,
            height: ring.rFactor * 2 * size,
            transitionDelay: `${i * 60}ms`,
          }}
          aria-hidden
        />
      ))}

      {/* ash moons — always orbiting, locked to their ring, never off-screen */}
      {RINGS.map((ring) => {
        const items = byCycle[ring.cycle];
        const r = ring.rFactor * size;
        const n = items.length;
        if (!n) return null;

        // (1) NO OVERLAP: cap diameter to a fraction of the arc between moons.
        const gap = (2 * Math.PI * r) / n;
        const maxByGap = gap * 0.62;
        // (2) NEVER OFF-SCREEN: the moon's outer edge must stay in the box.
        const maxByEdge = (size / 2 - r - EDGE_PAD) * 2;

        return items.map((sub, i) => {
          const phase = i / n; // evenly spaced around the ring
          const d = Math.max(
            size * 0.036,
            Math.min(costSize(sub), maxByGap, maxByEdge)
          );
          return (
            <motion.button
              key={sub.id}
              className={"sun-orbit__moon" + (revealed ? " is-revealed" : "")}
              style={{ width: d, height: d, marginLeft: -d / 2, marginTop: -d / 2 } as CSSProperties}
              initial={{ opacity: 0, scale: 0.2 }}
              animate={{
                opacity: 1,
                scale: 1,
                // sample x/y around the circle so the moon rides its ring and
                // can never drift off-orbit
                x: SAMPLES.map((t) => Math.cos(theta(phase + t * ring.dir)) * r),
                y: SAMPLES.map((t) => Math.sin(theta(phase + t * ring.dir)) * r),
              }}
              transition={{
                opacity: { duration: 0.4, delay: i * 0.03 },
                scale: { type: "spring", stiffness: 200, damping: 18, delay: i * 0.03 },
                x: { duration: ring.dur, ease: "linear", repeat: Infinity, times: SAMPLES },
                y: { duration: ring.dur, ease: "linear", repeat: Infinity, times: SAMPLES },
              }}
              onClick={(e) => {
                e.stopPropagation();
                if (revealed) onSelect?.(sub.id);
              }}
              tabIndex={revealed ? 0 : -1}
              title={revealed ? sub.name : undefined}
              aria-label={revealed ? `Open ${sub.name}` : undefined}
            >
              <MoonBody sub={sub} d={d} revealed={revealed} />
            </motion.button>
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
}

/** Evenly spaced keyframe samples across one lap (0 → 1). */
const STEPS = 64;
const SAMPLES = Array.from({ length: STEPS + 1 }, (_, i) => i / STEPS);

/** Angle in radians for a normalised position around the orbit. */
function theta(t: number) {
  return (t % 1) * Math.PI * 2;
}

/** The glowing orange→pink→magenta star at the centre. */
function Sun({ size }: { size: number }) {
  return (
    <motion.svg
      width={size}
      height={size}
      viewBox="0 0 100 100"
      style={{ display: "block", overflow: "visible" }}
      animate={{ scale: [1, 1.03, 1] }}
      transition={{ duration: 5, ease: "easeInOut", repeat: Infinity }}
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
    </motion.svg>
  );
}

/** A moon that flips between its plain ash face (default) and its brand logo
 *  (revealed). A single rotateY carries both faces for a physical coin-flip. */
function MoonBody({
  sub,
  d,
  revealed,
}: {
  sub: Subscription;
  d: number;
  revealed: boolean;
}) {
  return (
    <div className="sun-orbit__flip" style={{ width: d, height: d }}>
      <motion.div
        className="sun-orbit__flip-inner"
        animate={{ rotateY: revealed ? 180 : 0 }}
        transition={{ type: "spring", stiffness: 260, damping: 22 }}
      >
        <div className="sun-orbit__face sun-orbit__face--ash">
          <Moon d={d} />
        </div>
        <div className="sun-orbit__face sun-orbit__face--logo">
          <LogoTile sub={sub} d={d} />
        </div>
      </motion.div>
    </div>
  );
}

/** A plain, perfectly circular ash moon — soft top-left lighting, subtle rim. */
function Moon({ d }: { d: number }) {
  const id = "moon-" + Math.round(d * 10);
  return (
    <svg width={d} height={d} viewBox="0 0 100 100" style={{ display: "block" }}>
      <defs>
        <radialGradient id={id} cx="36%" cy="30%" r="78%">
          <stop offset="0%" stopColor="#e7e8ee" />
          <stop offset="46%" stopColor="#b9bcca" />
          <stop offset="80%" stopColor="#8b8fa2" />
          <stop offset="100%" stopColor="#5c6072" />
        </radialGradient>
      </defs>
      <circle cx="50" cy="50" r="47" fill={`url(#${id})`} />
      <circle cx="50" cy="50" r="46.4" fill="none" stroke="#ffffff" strokeWidth="1.2" opacity="0.16" />
    </svg>
  );
}

/** Revealed face: the subscription's brand colour + glyph, as a round tile so
 *  it stays a clean circle matching the moon it flips from. */
function LogoTile({ sub, d }: { sub: Subscription; d: number }) {
  return (
    <div
      className="sun-orbit__logo"
      style={{
        width: d,
        height: d,
        background: sub.color,
        fontSize: d * 0.44,
      }}
    >
      <span>{sub.mark}</span>
    </div>
  );
}
