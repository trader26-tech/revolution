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
          const t = costT(sub);
          const heat = heatColor(t, sub.flow === "income");
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
              <MoonBody
                sub={sub}
                d={d}
                revealed={revealed}
                index={i}
                heat={heat}
                // rotation (deg) that points the sphere's top highlight AT the
                // centre sun. Planet is at angle θ; direction to sun is θ+180°;
                // the highlight sits at the SVG top (−90°), so rotate θ+270°.
                sunAngle={SAMPLES.map(
                  (s) => theta(phase + s * ring.dir) * (180 / Math.PI) + 270
                )}
                dur={ring.dur}
              />
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

/** The colour of the small sun-glint on an otherwise silver planet. */
interface Heat {
  key: string; // stable id fragment for gradient uniqueness
  spot: string; // the flow-tinted sun-glint colour
  spotHi: string; // its bright core
}

/** The sun-glint colour: green for income, red for expense. Cost intensity
 *  t∈[0,1] just deepens/brightens the glint a touch, so pricier planets catch a
 *  slightly stronger coloured light — but the planet body stays silver. */
function heatColor(t: number, income: boolean): Heat {
  // playful but saturated so the lit hemisphere reads clearly as coloured
  const base = income ? "#2fd982" : "#ff4d68"; // green / red
  const hi = income ? "#8bffc0" : "#ff9aa8"; // brighter, near the sun-facing edge
  return {
    key: (income ? "i" : "e") + Math.round(t * 10),
    // pricier → a touch deeper coat; cheaper → a touch lighter
    spot: mix(base, income ? "#0f9e5a" : "#e01e3c", t * 0.5),
    spotHi: hi,
  };
}

/* ---- tiny colour helpers ---- */
function hexToRgb(hex: string) {
  const h = hex.replace("#", "");
  return {
    r: parseInt(h.slice(0, 2), 16),
    g: parseInt(h.slice(2, 4), 16),
    b: parseInt(h.slice(4, 6), 16),
  };
}
function toHex(n: number) {
  return Math.max(0, Math.min(255, Math.round(n))).toString(16).padStart(2, "0");
}
function mix(c1: string, c2: string, k: number) {
  const a = hexToRgb(c1);
  const b = hexToRgb(c2);
  return `#${toHex(a.r + (b.r - a.r) * k)}${toHex(a.g + (b.g - a.g) * k)}${toHex(
    a.b + (b.b - a.b) * k
  )}`;
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
  heat,
  sunAngle,
  dur,
}: {
  sub: Subscription;
  d: number;
  revealed: boolean;
  index: number;
  heat: Heat;
  sunAngle: number[];
  dur: number;
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
        {/* the ash planet is lit toward the sun: rotate the sphere so its bright
            (top) side always points at the centre. Only the sphere rotates —
            the logo face stays upright. */}
        <motion.div
          className="sun-orbit__face sun-orbit__face--ash"
          animate={{ rotate: sunAngle }}
          transition={{ duration: dur, ease: "linear", repeat: Infinity, times: SAMPLES }}
        >
          <Moon d={d} heat={heat} />
        </motion.div>
        <div className="sun-orbit__face sun-orbit__face--logo">
          <LogoTile sub={sub} d={d} />
        </div>
      </motion.div>
    </div>
  );
}

/** A plain SILVER/ash sphere. The ONLY colour is a small specular spot where
 *  the sun strikes — tinted by flow (green income / red expense). The spot is
 *  placed at the sun-facing edge (top of the SVG) and the parent rotates the
 *  sphere so that edge always faces the centre sun. The spot covers ≤7% of the
 *  surface (r ≈ 0.264·R), so the planet stays clearly silver. */
function Moon({ d, heat }: { d: number; heat: Heat }) {
  const id = "moon-" + Math.round(d * 10);
  const spot = "spot-" + heat.key + "-" + Math.round(d * 10);
  return (
    <svg width={d} height={d} viewBox="0 0 100 100" style={{ display: "block" }}>
      <defs>
        {/* the silver/ash body sphere: lit from the top (sun side) */}
        <radialGradient id={id} cx="50%" cy="32%" r="80%">
          <stop offset="0%" stopColor="#eceef4" />
          <stop offset="46%" stopColor="#c2c5d1" />
          <stop offset="80%" stopColor="#8f93a4" />
          <stop offset="100%" stopColor="#565a6d" />
        </radialGradient>
        {/* SUN-LIT COAT: the sun-facing HALF is coated solidly in the flow
            colour, then slopes down to transparent at the terminator (the
            middle), so the far hemisphere stays ash. Vertical: top = sun side.
            A soft sphere-shade multiplies over it so the coloured half still
            reads as a curved surface (brighter at the lit edge, darker in). */}
        <linearGradient id={spot} x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%" stopColor={heat.spotHi} stopOpacity="1" />
          <stop offset="20%" stopColor={heat.spot} stopOpacity="1" />
          <stop offset="42%" stopColor={heat.spot} stopOpacity="0.9" />
          <stop offset="55%" stopColor={heat.spot} stopOpacity="0.4" />
          <stop offset="70%" stopColor={heat.spot} stopOpacity="0.12" />
          <stop offset="100%" stopColor={heat.spot} stopOpacity="0" />
        </linearGradient>
        {/* radial shade to keep the coloured half looking spherical (lit at the
            sun edge, falling to shadow) */}
        <radialGradient id={spot + "-sh"} cx="50%" cy="26%" r="80%">
          <stop offset="0%" stopColor="#ffffff" stopOpacity="0.34" />
          <stop offset="46%" stopColor="#ffffff" stopOpacity="0" />
          <stop offset="100%" stopColor="#000000" stopOpacity="0.32" />
        </radialGradient>
        {/* clip the coat to the sphere so it never spills past the rim */}
        <clipPath id={id + "-clip"}>
          <circle cx="50" cy="50" r="47" />
        </clipPath>
      </defs>
      {/* ash sphere */}
      <circle cx="50" cy="50" r="47" fill={`url(#${id})`} />
      {/* coloured sun-lit hemisphere, clipped to the sphere */}
      <g clipPath={`url(#${id}-clip)`}>
        <rect x="0" y="0" width="100" height="100" fill={`url(#${spot})`} />
        {/* spherical shading over the coloured coat */}
        <rect x="0" y="0" width="100" height="100" fill={`url(#${spot}-sh)`} />
      </g>
      {/* faint rim so the planet reads as a sphere against space */}
      <circle cx="50" cy="50" r="46.4" fill="none" stroke="#ffffff" strokeWidth="1" opacity="0.12" />
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
