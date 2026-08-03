import { useMemo, useState } from "react";
import type { CSSProperties } from "react";
import { motion } from "framer-motion";
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

/** The three billing cycles, mapped to rings from the inside out:
 *  weekly (fastest, closest) → monthly → yearly (slowest, farthest).
 *  All rings spin the SAME way — clockwise on screen (dir = 1) — only their
 *  speed differs, so the system reads as one coherent solar system. */
const RINGS: { cycle: Cycle; rFactor: number; dur: number; dir: 1 | -1 }[] = [
  { cycle: "weekly", rFactor: 0.22, dur: 26, dir: 1 },
  { cycle: "monthly", rFactor: 0.31, dur: 40, dir: 1 },
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

  // Median monthly cost — the midpoint of the sigmoid so a couple of pricey
  // outliers don't wash the whole scale to one extreme.
  const median = useMemo(() => {
    if (!subs.length) return 1;
    const c = subs.map((s) => monthly(s.amount, s.cycle)).sort((a, b) => a - b);
    const mid = Math.floor(c.length / 2);
    return c.length % 2 ? c[mid] : (c[mid - 1] + c[mid]) / 2;
  }, [subs]);

  /** Cost intensity 0→1 via a sigmoid around the median. Cheap → 0, pricey → 1;
   *  drives BOTH the planet size and its heat colour. */
  const costT = (s: Subscription) => {
    const c = monthly(s.amount, s.cycle);
    const x = Math.log((c + 1) / (median + 1)); // 0 at the median
    return 1 / (1 + Math.exp(-1.1 * x));
  };

  /** Cost-driven moon diameter within [floor, ceil]. */
  const costSize = (s: Subscription) => {
    const floor = size * 0.05;
    const ceil = size * 0.1;
    return floor + (ceil - floor) * costT(s);
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
              style={
                {
                  width: d,
                  height: d,
                  marginLeft: -d / 2,
                  marginTop: -d / 2,
                  // no glow — only a soft dark drop for depth against space
                  filter: "drop-shadow(0 4px 8px rgba(0,0,0,0.5))",
                } as CSSProperties
              }
              initial={{ opacity: 0, scale: 0.2 }}
              animate={{
                opacity: 1,
                scale: 1,
                // sample x/y around the circle so the moon rides its ring and
                // can never drift off-orbit
                x: SAMPLES.map((s) => Math.cos(theta(phase + s * ring.dir)) * r),
                y: SAMPLES.map((s) => Math.sin(theta(phase + s * ring.dir)) * r),
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
              <MoonBody sub={sub} d={d} revealed={revealed} index={i} />
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
  index,
}: {
  sub: Subscription;
  d: number;
  revealed: boolean;
  index: number;
}) {
  return (
    <div className="sun-orbit__flip" style={{ width: d, height: d }}>
      <motion.div
        className="sun-orbit__flip-inner"
        animate={{ rotateY: revealed ? 180 : 0 }}
        transition={{
          // a slow, smooth flip — no spring bounce, gentle ease. Moons flip
          // in a soft cascade (staggered by index) rather than all at once.
          duration: 0.9,
          ease: [0.4, 0, 0.2, 1],
          delay: index * 0.07,
        }}
      >
        <div className="sun-orbit__face sun-orbit__face--ash">
          <Moon d={d} income={sub.flow === "income"} />
        </div>
        <div className="sun-orbit__face sun-orbit__face--logo">
          <LogoTile sub={sub} d={d} />
        </div>
      </motion.div>
    </div>
  );
}

/** A plain silver/ash sphere. Differentiation is by SHAPE, not colour:
 *  - expense → a bare silver planet
 *  - income  → the same silver planet wearing a soft silver-white halo ring.
 *  The ring is the whole signal, so there's no colour-matching to get wrong. */
function Moon({ d, income }: { d: number; income: boolean }) {
  const id = "moon-" + Math.round(d * 10);
  return (
    // extra viewBox room so the halo ring isn't clipped at the edges
    <svg width={d} height={d} viewBox="-16 -16 132 132" style={{ display: "block", overflow: "visible" }}>
      <defs>
        {/* the silver/ash body sphere, lit softly from the top-left */}
        <radialGradient id={id} cx="38%" cy="30%" r="82%">
          <stop offset="0%" stopColor="#eceef4" />
          <stop offset="46%" stopColor="#c2c5d1" />
          <stop offset="80%" stopColor="#8f93a4" />
          <stop offset="100%" stopColor="#565a6d" />
        </radialGradient>
        <filter id={id + "-glow"} x="-40%" y="-40%" width="180%" height="180%">
          <feGaussianBlur stdDeviation="2.4" />
        </filter>
      </defs>

      {/* INCOME halo ring — a bigger, soft silver-white ring around the planet.
          Expenses render none of this: a bare silver planet. */}
      {income && (
        <>
          {/* soft outer glow */}
          <circle
            cx="50"
            cy="50"
            r="61"
            fill="none"
            stroke="#f2f4ff"
            strokeWidth="6"
            opacity="0.28"
            filter={`url(#${id}-glow)`}
          />
          {/* crisp bright ring */}
          <circle
            cx="50"
            cy="50"
            r="61"
            fill="none"
            stroke="#eef1fb"
            strokeWidth="3"
            opacity="0.9"
          />
        </>
      )}

      {/* silver sphere */}
      <circle cx="50" cy="50" r="47" fill={`url(#${id})`} />
      {/* faint bright rim so the sphere reads as 3D */}
      <circle cx="50" cy="50" r="46.4" fill="none" stroke="#ffffff" strokeWidth="1" opacity="0.14" />
    </svg>
  );
}

/** Revealed face: the subscription's real brand logo (or a tinted initial),
 *  as a round tile so it stays a clean circle matching the moon it flips from. */
function LogoTile({ sub, d }: { sub: Subscription; d: number }) {
  return (
    <BrandLogo
      name={sub.name}
      brandSlug={sub.brandSlug}
      mark={sub.mark}
      fallbackColor={sub.color}
      size={d}
      radius={d / 2}
    />
  );
}
