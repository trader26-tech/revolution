import { useMemo } from "react";
import "./space-background.css";

/** Full-screen deep-space backdrop shared by every screen.
 *
 *  Three star layers give parallax depth:
 *   - far:  many tiny dim stars, slow collective drift
 *   - mid:  fewer, brighter stars that twinkle
 *   - near: a handful of large stars with a soft glow + crisp twinkle
 *
 *  Individual twinkle timing is randomised per star (deterministically, so it
 *  doesn't reshuffle between renders) so the field never pulses in unison.
 *  Everything is CSS-driven; motion is disabled under prefers-reduced-motion.
 */
export function SpaceBackground() {
  const far = useMemo(() => makeStars("far", 60), []);
  const mid = useMemo(() => makeStars("mid", 34), []);
  const near = useMemo(() => makeStars("near", 14), []);

  return (
    <div className="space" aria-hidden>
      <div className="space__nebula" />
      <div className="space__layer space__layer--far">
        {far.map((s, i) => (
          <Star key={i} s={s} />
        ))}
      </div>
      <div className="space__layer space__layer--mid">
        {mid.map((s, i) => (
          <Star key={i} s={s} />
        ))}
      </div>
      <div className="space__layer space__layer--near">
        {near.map((s, i) => (
          <Star key={i} s={s} />
        ))}
      </div>

      {/* an occasional shooting star sweeps across, then waits a long while */}
      <span className="space__shooting space__shooting--a" />
      <span className="space__shooting space__shooting--b" />
    </div>
  );
}

function Star({ s }: { s: StarSpec }) {
  return (
    <span
      className="space__star"
      style={{
        left: `${s.x}%`,
        top: `${s.y}%`,
        width: `${s.size}px`,
        height: `${s.size}px`,
        // twinkle timing, staggered per star
        animationDuration: `${s.dur}s`,
        animationDelay: `${s.delay}s`,
        // dimmest opacity the twinkle floors out at
        ["--min" as string]: s.min,
      }}
    />
  );
}

interface StarSpec {
  x: number;
  y: number;
  size: number;
  dur: number;
  delay: number;
  min: number;
}

/** Deterministic PRNG seeded per layer, so stars stay put across renders. */
function makeStars(seedKey: string, count: number): StarSpec[] {
  let seed = 2166136261;
  for (const ch of seedKey) seed = (seed ^ ch.charCodeAt(0)) * 16777619;
  const rnd = () => {
    seed = (seed * 1103515245 + 12345) & 0x7fffffff;
    return seed / 0x7fffffff;
  };

  const cfg =
    seedKey === "near"
      ? { min: 1.6, max: 2.6, dmin: 2.4, dmax: 4.2, omin: 0.25 }
      : seedKey === "mid"
      ? { min: 1.1, max: 1.8, dmin: 3, dmax: 6, omin: 0.18 }
      : { min: 0.7, max: 1.3, dmin: 4, dmax: 8, omin: 0.1 };

  return Array.from({ length: count }, () => ({
    x: rnd() * 100,
    y: rnd() * 100,
    size: cfg.min + rnd() * (cfg.max - cfg.min),
    dur: cfg.dmin + rnd() * (cfg.dmax - cfg.dmin),
    delay: -rnd() * cfg.dmax,
    min: cfg.omin,
  }));
}
