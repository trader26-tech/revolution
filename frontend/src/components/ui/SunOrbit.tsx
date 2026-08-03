import { useMemo } from "react";
import type { CSSProperties } from "react";
import { motion } from "framer-motion";
import type { Cycle, Subscription } from "@/lib/types";
import { monthly } from "@/lib/money";
import "./sun-orbit.css";

interface Props {
  subs: Subscription[];
  size?: number;
  /** Tapping a moon opens that subscription. */
  onSelect?: (id: string) => void;
}

/** The three billing cycles, mapped to rings from the inside out:
 *  weekly (fastest, closest) → monthly → yearly (slowest, farthest). */
const RINGS: { cycle: Cycle; rFactor: number; dur: number; dir: 1 | -1 }[] = [
  { cycle: "weekly", rFactor: 0.24, dur: 26, dir: 1 },
  { cycle: "monthly", rFactor: 0.335, dur: 40, dir: -1 },
  { cycle: "yearly", rFactor: 0.43, dur: 58, dir: 1 },
];

/** The home hero: a warm glowing sun ringed by three clean orbits — one per
 *  billing cycle. Each subscription rides *its* cycle's ring as a plain ash
 *  moon, sized by cost. Moons on the same ring are guaranteed never to
 *  overlap: their size is capped to the spacing available on that ring.
 *  Tapping a moon opens its subscription. */
export function SunOrbit({ subs, size = 300, onSelect }: Props) {
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
    const ceil = size * 0.11;
    const c = monthly(s.amount, s.cycle);
    const t = maxCost === minCost ? 0.5 : (c - minCost) / (maxCost - minCost);
    return floor + (ceil - floor) * t;
  };

  return (
    <div className="sun-orbit" style={{ width: size, height: size }}>
      {/* three clean orbit guide rings */}
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

      {/* ash moons — always visible, always tappable, locked to their ring */}
      {RINGS.map((ring) => {
        const items = byCycle[ring.cycle];
        const r = ring.rFactor * size;
        const n = items.length;
        if (!n) return null;

        // NO-OVERLAP GUARANTEE: the arc between two adjacent, evenly-spaced
        // moons is (2πr / n). Cap each moon's diameter to a fraction of that
        // gap (with margin) so neighbours can never touch — whatever the size.
        const gap = (2 * Math.PI * r) / n;
        const maxByGap = gap * 0.62; // leave clear space between moons

        return items.map((sub, i) => {
          const phase = i / n; // evenly spaced around the ring
          const d = Math.max(size * 0.038, Math.min(costSize(sub), maxByGap));
          return (
            <motion.button
              key={sub.id}
              className="sun-orbit__moon"
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
                onSelect?.(sub.id);
              }}
              title={sub.name}
              aria-label={`Open ${sub.name}`}
            >
              <Moon d={d} />
            </motion.button>
          );
        });
      })}

      {/* the sun — non-interactive centrepiece */}
      <div
        className="sun-orbit__sun"
        style={{ width: size * 0.34, height: size * 0.34 }}
        aria-hidden
      >
        <Sun size={size * 0.34} />
      </div>
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

/** A plain, perfectly circular ash moon — soft top-left lighting, subtle rim.
 *  No letters, no craters: clean and minimal, matching the reference. */
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
      {/* soft rim light for a little depth */}
      <circle cx="50" cy="50" r="46.4" fill="none" stroke="#ffffff" strokeWidth="1.2" opacity="0.16" />
    </svg>
  );
}
