import { useMemo, useState } from "react";
import type { CSSProperties } from "react";
import { motion } from "framer-motion";
import type { Cycle, Subscription } from "@/lib/types";
import { monthly } from "@/lib/money";
import "./sun-orbit.css";

interface Props {
  subs: Subscription[];
  size?: number;
  /** Tapping a planet opens that subscription. */
  onSelect?: (id: string) => void;
}

/** The three billing cycles, mapped to rings from the inside out:
 *  weekly (fastest, closest) → monthly → yearly (slowest, farthest). */
const RINGS: { cycle: Cycle; rFactor: number; dur: number; dir: 1 | -1 }[] = [
  { cycle: "weekly", rFactor: 0.24, dur: 26, dir: 1 },
  { cycle: "monthly", rFactor: 0.335, dur: 40, dir: -1 },
  { cycle: "yearly", rFactor: 0.43, dur: 58, dir: 1 },
];

/** The signature home hero: a glowing sun ringed by three orbits — one per
 *  billing cycle. Subscriptions always ride *their cycle's* ring as ash-grey
 *  asteroids, sized by cost via a sigmoid. Tapping the sun flips every asteroid
 *  to reveal its brand logo (tap again to hide). Only a *revealed* logo is
 *  tappable, and tapping it opens that subscription's cost sheet. */
export function SunOrbit({ subs, size = 272, onSelect }: Props) {
  // `revealed` = logos are showing. Asteroids themselves are always present.
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

  // Median monthly cost — the sigmoid's midpoint, so "typical" subs land in the
  // middle of the size range and outliers approach the min/max asymptotes.
  const median = useMemo(() => {
    if (!subs.length) return 1;
    const costs = subs.map((s) => monthly(s.amount, s.cycle)).sort((a, b) => a - b);
    const mid = Math.floor(costs.length / 2);
    return costs.length % 2 ? costs[mid] : (costs[mid - 1] + costs[mid]) / 2;
  }, [subs]);

  /** Sigmoid size: always within [min, max], smoothly rising with cost.
   *  min keeps cheap planets clearly visible; max caps the biggest. */
  const planetSize = (s: Subscription) => {
    const min = size * 0.058; // fairly visible floor
    const max = size * 0.125; // max allowable circle
    const cost = monthly(s.amount, s.cycle);
    // logistic around the median; k controls how fast it saturates
    const k = 1.1;
    const x = Math.log((cost + 1) / (median + 1)); // 0 at the median
    const t = 1 / (1 + Math.exp(-k * x)); // (0,1), 0.5 at the median
    return min + (max - min) * t;
  };

  const hasSubs = subs.length > 0;

  return (
    <div className="sun-orbit" style={{ width: size, height: size }}>
      {/* three orbit guide rings — brighten while logos are revealed */}
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

      {/* asteroids — ALWAYS orbiting; each locked to its ring by per-frame
          position sampling. Tapping the sun flips them to their logos. */}
      {RINGS.map((ring) => {
        const items = byCycle[ring.cycle];
        const r = ring.rFactor * size;
        const n = Math.max(items.length, 1);
        return items.map((sub, i) => {
          const phase = i / n; // evenly spaced around the ring
          const d = planetSize(sub);
          return (
            <motion.button
              key={sub.id}
              className={
                "sun-orbit__body" + (revealed ? " is-revealed" : "")
              }
              style={{ width: d, height: d, marginLeft: -d / 2, marginTop: -d / 2 } as CSSProperties}
              initial={{ opacity: 0, scale: 0.2 }}
              animate={{
                opacity: 1,
                scale: 1,
                // sample x/y around the circle so framer interpolates the body
                // ALONG the ring — it can never leave the orbit
                x: SAMPLES.map((t) => Math.cos(theta(phase + t * ring.dir)) * r),
                y: SAMPLES.map((t) => Math.sin(theta(phase + t * ring.dir)) * r),
              }}
              transition={{
                opacity: { duration: 0.4, delay: i * 0.03 },
                scale: { type: "spring", stiffness: 200, damping: 18, delay: i * 0.03 },
                x: { duration: ring.dur, ease: "linear", repeat: Infinity, times: SAMPLES },
                y: { duration: ring.dur, ease: "linear", repeat: Infinity, times: SAMPLES },
              }}
              // Only a revealed logo is actionable; a raw asteroid is inert.
              onClick={(e) => {
                e.stopPropagation();
                if (revealed) onSelect?.(sub.id);
              }}
              tabIndex={revealed ? 0 : -1}
              aria-hidden={!revealed}
              title={revealed ? sub.name : undefined}
              aria-label={revealed ? `Open ${sub.name}` : undefined}
            >
              <BodyFace sub={sub} d={d} revealed={revealed} />
            </motion.button>
          );
        });
      })}

      {/* the sun — tap to reveal / hide the logos */}
      <button
        className={"sun-orbit__sun" + (revealed ? " is-open" : "")}
        style={{ width: size * 0.34, height: size * 0.34 }}
        onClick={() => hasSubs && setRevealed((v) => !v)}
        aria-label={revealed ? "Hide logos" : "Reveal logos"}
      >
        <Sun size={size * 0.34} />
        {hasSubs && (
          <span className={"sun-orbit__hint" + (revealed ? " is-hidden" : "")}>
            Tap
          </span>
        )}
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

/** A body that flips between its asteroid rock (default) and its brand logo
 *  (revealed). A single 3D rotateY carries both faces so the reveal reads as a
 *  physical coin-flip. */
function BodyFace({
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
        <div className="sun-orbit__face sun-orbit__face--rock">
          <Asteroid sub={sub} d={d} />
        </div>
        <div className="sun-orbit__face sun-orbit__face--logo">
          <LogoTile sub={sub} d={d} />
        </div>
      </motion.div>
    </div>
  );
}

/** A muted, cratered space rock. Crater layout is seeded from the id so each
 *  asteroid looks distinct but stable across renders. */
function Asteroid({ sub, d }: { sub: Subscription; d: number }) {
  const id = "rock-" + sub.id;
  const craters = useMemo(() => makeCraters(sub.id), [sub.id]);
  return (
    <svg width={d} height={d} viewBox="0 0 100 100" style={{ display: "block" }}>
      <defs>
        <radialGradient id={id} cx="34%" cy="28%" r="82%">
          <stop offset="0%" stopColor="#c3c6d2" />
          <stop offset="42%" stopColor="#8f93a6" />
          <stop offset="76%" stopColor="#565a6d" />
          <stop offset="100%" stopColor="#2b2d3f" />
        </radialGradient>
        <radialGradient id={id + "-lit"} cx="30%" cy="24%" r="42%">
          <stop offset="0%" stopColor="#ffffff" stopOpacity="0.5" />
          <stop offset="100%" stopColor="#ffffff" stopOpacity="0" />
        </radialGradient>
      </defs>
      {/* slightly irregular silhouette so it doesn't read as a perfect ball */}
      <path
        d="M50 4C68 4 79 14 88 30C97 46 96 66 84 80C72 94 54 97 38 92C20 87 7 72 5 52C3 32 16 14 34 8C39 6 45 4 50 4Z"
        fill={`url(#${id})`}
      />
      {craters.map((c, i) => (
        <g key={i}>
          <circle cx={c.x} cy={c.y} r={c.r} fill="#00000030" />
          <circle cx={c.x - c.r * 0.28} cy={c.y - c.r * 0.28} r={c.r * 0.7} fill="#ffffff12" />
        </g>
      ))}
      {/* specular highlight, upper-left */}
      <ellipse cx="36" cy="30" rx="22" ry="16" fill={`url(#${id}-lit)`} />
      <path
        d="M50 4C68 4 79 14 88 30C97 46 96 66 84 80C72 94 54 97 38 92C20 87 7 72 5 52C3 32 16 14 34 8C39 6 45 4 50 4Z"
        fill="none"
        stroke="#ffffff"
        strokeWidth="1"
        opacity="0.12"
      />
    </svg>
  );
}

/** The revealed brand tile: the subscription's colour + glyph, glossy. */
function LogoTile({ sub, d }: { sub: Subscription; d: number }) {
  return (
    <div
      className="sun-orbit__logo"
      style={{
        width: d,
        height: d,
        background: sub.color,
        borderRadius: d * 0.28,
        fontSize: d * 0.42,
      }}
    >
      <span>{sub.mark}</span>
    </div>
  );
}

interface Crater {
  x: number;
  y: number;
  r: number;
}

/** Deterministic crater placement seeded from the subscription id. */
function makeCraters(seedKey: string): Crater[] {
  let seed = 2166136261;
  for (const ch of seedKey) seed = (seed ^ ch.charCodeAt(0)) * 16777619;
  const rnd = () => {
    seed = (seed * 1103515245 + 12345) & 0x7fffffff;
    return seed / 0x7fffffff;
  };
  const count = 3 + Math.floor(rnd() * 2);
  return Array.from({ length: count }, () => ({
    x: 26 + rnd() * 48,
    y: 24 + rnd() * 50,
    r: 3 + rnd() * 6,
  }));
}
