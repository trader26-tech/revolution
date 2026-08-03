import { useMemo } from "react";
import "./space-background.css";

/** Full-screen deep-space backdrop shared by every screen.
 *
 *  PERFORMANCE NOTE — why this is not 100+ elements:
 *  Each star used to be its own <span> with `will-change`, which promoted every
 *  one to its own GPU compositor layer (~110 layers). On real phones that
 *  thrashes GPU memory and is the single biggest source of jank. Instead each
 *  depth layer is now ONE element whose stars are painted as a single
 *  `background-image` of tiny radial gradients. The whole layer is then
 *  animated with one transform + one opacity — 3 cheap composited layers total,
 *  no per-star work, identical visuals.
 */
export function SpaceBackground() {
  // Built once; the gradient strings never change, so React never re-renders
  // this subtree and the browser paints each layer exactly once.
  const layers = useMemo(
    () => [
      { cls: "space__layer--far", bg: starField("far", 60) },
      { cls: "space__layer--mid", bg: starField("mid", 34) },
      { cls: "space__layer--near", bg: starField("near", 14) },
    ],
    []
  );

  return (
    <div className="space" aria-hidden>
      {layers.map((l) => (
        <div
          key={l.cls}
          className={`space__layer ${l.cls}`}
          style={{ backgroundImage: l.bg }}
        />
      ))}
    </div>
  );
}

/** Paint `count` stars for one depth layer as a single background-image.
 *  Returns a comma-separated list of tiny radial-gradients. */
function starField(seedKey: string, count: number): string {
  const rnd = seededRandom(seedKey);

  // size range + peak brightness per depth
  const cfg =
    seedKey === "near"
      ? { min: 1.6, max: 2.6, alpha: 0.95 }
      : seedKey === "mid"
      ? { min: 1.1, max: 1.8, alpha: 0.75 }
      : { min: 0.7, max: 1.3, alpha: 0.55 };

  const stops: string[] = [];
  for (let i = 0; i < count; i++) {
    const x = (rnd() * 100).toFixed(2);
    const y = (rnd() * 100).toFixed(2);
    const r = (cfg.min + rnd() * (cfg.max - cfg.min)).toFixed(2);
    // vary brightness per star so the field reads as depth, not a grid
    const a = (cfg.alpha * (0.55 + rnd() * 0.45)).toFixed(2);
    stops.push(
      `radial-gradient(${r}px ${r}px at ${x}% ${y}%, rgba(255,255,255,${a}) 0%, rgba(255,255,255,0) 60%)`
    );
  }
  return stops.join(",");
}

/** Deterministic PRNG seeded per layer, so the field never reshuffles. */
function seededRandom(seedKey: string) {
  let seed = 2166136261;
  for (const ch of seedKey) seed = (seed ^ ch.charCodeAt(0)) * 16777619;
  return () => {
    seed = (seed * 1103515245 + 12345) & 0x7fffffff;
    return seed / 0x7fffffff;
  };
}
