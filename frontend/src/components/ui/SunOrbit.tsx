import { useMemo, useState } from "react";
import type { CSSProperties } from "react";
import { AnimatePresence, motion } from "framer-motion";
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
 *  billing cycle. Subscriptions ride *their cycle's* ring as ash-grey planets,
 *  sized by cost via a sigmoid (cheap = small but clearly visible, costly =
 *  large, capped). Planets are hidden until the sun is tapped, then they bloom
 *  onto their rings and orbit; tapping again retracts them. */
export function SunOrbit({ subs, size = 272, onSelect }: Props) {
  const [open, setOpen] = useState(false);

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
      {/* three orbit guide rings, dim until opened */}
      {RINGS.map((ring, i) => (
        <div
          key={ring.cycle}
          className={"sun-orbit__ring" + (open ? " is-open" : "")}
          style={{
            width: ring.rFactor * 2 * size,
            height: ring.rFactor * 2 * size,
            transitionDelay: `${i * 60}ms`,
          }}
          aria-hidden
        />
      ))}

      {/* ash planets — each locked to its ring by per-frame position sampling */}
      {RINGS.map((ring) => {
        const items = byCycle[ring.cycle];
        const r = ring.rFactor * size;
        const n = Math.max(items.length, 1);
        return (
          <AnimatePresence key={"g-" + ring.cycle}>
            {open &&
              items.map((sub, i) => {
                const phase = i / n; // evenly spaced around the ring
                const d = planetSize(sub);
                return (
                  <motion.button
                    key={sub.id}
                    className="sun-orbit__planet"
                    style={{ width: d, height: d, marginLeft: -d / 2, marginTop: -d / 2 } as CSSProperties}
                    initial={{ opacity: 0, scale: 0.2 }}
                    animate={{
                      opacity: 1,
                      scale: 1,
                      // sample x/y around the circle so framer interpolates the
                      // planet ALONG the ring — it can never leave the orbit
                      x: SAMPLES.map((t) => Math.cos(theta(phase + t * ring.dir)) * r),
                      y: SAMPLES.map((t) => Math.sin(theta(phase + t * ring.dir)) * r),
                    }}
                    exit={{ opacity: 0, scale: 0.2 }}
                    transition={{
                      opacity: { duration: 0.35, delay: i * 0.04 },
                      scale: {
                        type: "spring",
                        stiffness: 200,
                        damping: 16,
                        delay: i * 0.04,
                      },
                      x: { duration: ring.dur, ease: "linear", repeat: Infinity, times: SAMPLES },
                      y: { duration: ring.dur, ease: "linear", repeat: Infinity, times: SAMPLES },
                    }}
                    onClick={(e) => {
                      e.stopPropagation();
                      onSelect?.(sub.id);
                    }}
                    title={sub.name}
                    aria-label={sub.name}
                  >
                    <AshPlanet name={sub.name} d={d} />
                  </motion.button>
                );
              })}
          </AnimatePresence>
        );
      })}

      {/* the sun — tap to reveal / hide the planets */}
      <button
        className={"sun-orbit__sun" + (open ? " is-open" : "")}
        style={{ width: size * 0.34, height: size * 0.34 }}
        onClick={() => hasSubs && setOpen((v) => !v)}
        aria-label={open ? "Hide subscriptions" : "Show subscriptions"}
      >
        <Sun size={size * 0.34} />
        {hasSubs && (
          <span className={"sun-orbit__hint" + (open ? " is-hidden" : "")}>Tap</span>
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

/** A muted ash-grey world with a faint initial. */
function AshPlanet({ name, d }: { name: string; d: number }) {
  const initial = name.trim().charAt(0).toUpperCase();
  const id = "ash-" + Math.round(d);
  return (
    <svg width={d} height={d} viewBox="0 0 100 100" style={{ display: "block" }}>
      <defs>
        <radialGradient id={id} cx="36%" cy="30%" r="80%">
          <stop offset="0%" stopColor="#c7c9d4" />
          <stop offset="45%" stopColor="#9195a6" />
          <stop offset="78%" stopColor="#5d6172" />
          <stop offset="100%" stopColor="#33364a" />
        </radialGradient>
      </defs>
      <circle cx="50" cy="50" r="46" fill={`url(#${id})`} />
      <circle cx="36" cy="38" r="7" fill="#00000022" />
      <circle cx="62" cy="58" r="5" fill="#00000022" />
      <circle cx="54" cy="30" r="3.5" fill="#00000022" />
      <text
        x="50"
        y="52"
        textAnchor="middle"
        dominantBaseline="central"
        fontSize="36"
        fontWeight="800"
        fill="#ffffff"
        opacity="0.55"
        fontFamily="Inter, sans-serif"
      >
        {initial}
      </text>
      <circle cx="50" cy="50" r="45.5" fill="none" stroke="#ffffff" strokeWidth="1" opacity="0.14" />
    </svg>
  );
}
