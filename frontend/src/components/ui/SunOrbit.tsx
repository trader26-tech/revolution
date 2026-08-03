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
  { cycle: "weekly", rFactor: 0.24, dur: 22, dir: 1 },
  { cycle: "monthly", rFactor: 0.335, dur: 34, dir: -1 },
  { cycle: "yearly", rFactor: 0.43, dur: 52, dir: 1 },
];

/** The signature home hero: a glowing sun ringed by three orbits — one per
 *  billing cycle. Subscriptions ride their cycle's ring as ash-grey planets,
 *  sized by cost (cheap = small, costly = large). The planets are hidden until
 *  the sun is tapped, then they bloom outward and orbit; tapping again retracts
 *  them into the sun. Tapping a planet opens its subscription. */
export function SunOrbit({ subs, size = 300, onSelect }: Props) {
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

  // Cost range across everything, for continuous planet sizing.
  const [minCost, maxCost] = useMemo(() => {
    if (!subs.length) return [0, 1];
    const costs = subs.map((s) => monthly(s.amount, s.cycle));
    return [Math.min(...costs), Math.max(...costs)];
  }, [subs]);

  const planetSize = (s: Subscription) => {
    const c = monthly(s.amount, s.cycle);
    const t = maxCost === minCost ? 0.5 : (c - minCost) / (maxCost - minCost);
    // clamp so cheap reads clearly small, costly clearly big
    const min = size * 0.052;
    const max = size * 0.11;
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

      {/* ash planets, one rotating group per ring */}
      {RINGS.map((ring) => {
        const items = byCycle[ring.cycle];
        const r = ring.rFactor * size;
        return (
          <AnimatePresence key={"g-" + ring.cycle}>
            {open &&
              items.map((sub, i) => {
                const angle = (i / items.length) * 360;
                const d = planetSize(sub);
                return (
                  <motion.div
                    key={sub.id}
                    className="sun-orbit__spin"
                    style={{ width: r * 2, height: r * 2 } as CSSProperties}
                    initial={{ opacity: 0, scale: 0.2, rotate: angle }}
                    animate={{
                      opacity: 1,
                      scale: 1,
                      rotate: angle + 360 * ring.dir,
                    }}
                    exit={{ opacity: 0, scale: 0.2 }}
                    transition={{
                      opacity: { duration: 0.4, delay: i * 0.04 },
                      scale: {
                        type: "spring",
                        stiffness: 180,
                        damping: 14,
                        delay: i * 0.04,
                      },
                      rotate: { duration: ring.dur, ease: "linear", repeat: Infinity },
                    }}
                  >
                    {/* planet sits at the top of the spinning square, counter-
                        rotates so it never spins on its own axis */}
                    <motion.button
                      className="sun-orbit__planet"
                      style={{ width: d, height: d } as CSSProperties}
                      animate={{ rotate: -(angle + 360 * ring.dir) }}
                      transition={{ duration: ring.dur, ease: "linear", repeat: Infinity }}
                      onClick={(e) => {
                        e.stopPropagation();
                        onSelect?.(sub.id);
                      }}
                      title={sub.name}
                      aria-label={sub.name}
                    >
                      <AshPlanet name={sub.name} d={d} />
                    </motion.button>
                  </motion.div>
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
          <span className={"sun-orbit__hint" + (open ? " is-hidden" : "")}>
            Tap
          </span>
        )}
      </button>
    </div>
  );
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
      {/* soft outer glow */}
      <circle cx="50" cy="50" r="66" fill="url(#sun-halo)" />
      {/* body */}
      <circle cx="50" cy="50" r="42" fill="url(#sun-core)" />
      {/* subtle surface swirl */}
      <ellipse cx="44" cy="40" rx="26" ry="18" fill="#ffb15a" opacity="0.35" />
      <ellipse cx="58" cy="62" rx="22" ry="14" fill="#ff2d78" opacity="0.3" />
      {/* rim */}
      <circle cx="50" cy="50" r="42" fill="none" stroke="#ffd9a8" strokeWidth="1" opacity="0.4" />
    </motion.svg>
  );
}

/** A muted ash-grey world. Two-letter/one-letter initial shows faintly so the
 *  planets still read as distinct without colourful branding. */
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
      {/* craters for texture */}
      <circle cx="36" cy="38" r="7" fill="#00000022" />
      <circle cx="62" cy="58" r="5" fill="#00000022" />
      <circle cx="54" cy="30" r="3.5" fill="#00000022" />
      {/* faint initial */}
      <text
        x="50"
        y="50"
        textAnchor="middle"
        dominantBaseline="central"
        fontSize="34"
        fontWeight="800"
        fill="#ffffff"
        opacity="0.5"
        fontFamily="Inter, sans-serif"
      >
        {initial}
      </text>
      {/* rim light */}
      <circle cx="50" cy="50" r="45.5" fill="none" stroke="#ffffff" strokeWidth="1" opacity="0.14" />
    </svg>
  );
}
