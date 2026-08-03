import { useMemo } from "react";
import type { CSSProperties } from "react";
import { motion } from "framer-motion";
import { Planet } from "./Planet";
import type { Subscription } from "@/lib/types";
import "./orbit-hero.css";

interface Props {
  subs: Subscription[];
  size?: number;
  /** Net flow of the visible set — tints the central planet's key light. */
  flow?: "income" | "expense";
  onSelect?: (id: string) => void;
}

/** The signature animation: subscription logos ride tilted orbits around a
 *  central planet. Rings counter-rotate at different speeds; each chip
 *  counter-rotates to stay upright, dims as it passes behind the planet, and
 *  carries a coloured ring for income vs expense. */
export function OrbitHero({ subs, size = 300, flow, onSelect }: Props) {
  const items = subs.slice(0, 10);

  // Deterministic star field, regenerated only when the box resizes.
  const stars = useMemo(() => makeStars(46, size), [size]);

  const rings = [
    { r: size * 0.355, dur: 32, dir: 1, tilt: 12, chip: size * 0.115, chips: items.filter((_, i) => i % 2 === 0) },
    { r: size * 0.475, dur: 48, dir: -1, tilt: 12, chip: size * 0.102, chips: items.filter((_, i) => i % 2 === 1) },
  ];

  return (
    <div className="orbit-hero" style={{ width: size, height: size }}>
      {/* deep-space star field behind everything */}
      <div className="orbit-hero__stars" aria-hidden>
        {stars.map((s, i) => (
          <span
            key={i}
            className="orbit-hero__star"
            style={{
              left: s.x,
              top: s.y,
              width: s.r,
              height: s.r,
              opacity: s.o,
              animationDelay: `${s.delay}s`,
              animationDuration: `${s.dur}s`,
            }}
          />
        ))}
      </div>

      <div className={"orbit-hero__glow" + (flow ? ` is-${flow}` : "")} />

      {/* tilted orbit guides — the ellipse sells the 3D plane */}
      {rings.map((ring, ri) => (
        <div
          key={"g" + ri}
          className="orbit-hero__guide"
          style={{
            width: ring.r * 2,
            height: ring.r * 2 * 0.42,
            transform: `translate(-50%,-50%) rotate(${ring.tilt}deg)`,
          }}
        />
      ))}

      {/* orbiting chips — position is computed on an ellipse each frame, so the
          chips translate along a tilted path without ever being scaled/sheared. */}
      {rings.map((ring, ri) =>
        ring.chips.map((sub, i) => {
          const n = Math.max(ring.chips.length, 1);
          const phase = i / n;
          const isIncome = sub.flow === "income";
          return (
            <motion.button
              key={sub.id + ri}
              className={
                "orbit-hero__chip" + (isIncome ? " is-income" : " is-expense")
              }
              style={
                {
                  "--chip": `${ring.chip}px`,
                  width: ring.chip,
                  height: ring.chip,
                  background: sub.color,
                  fontSize: ring.chip * 0.42,
                } as CSSProperties
              }
              animate={{
                // one full lap, sampled so framer interpolates along the ellipse
                x: SAMPLES.map((t) =>
                  ellipseX(phase + t * ring.dir, ring.r, ring.tilt)
                ),
                y: SAMPLES.map((t) =>
                  ellipseY(phase + t * ring.dir, ring.r, ring.tilt)
                ),
                // chips further "back" sit slightly smaller and dimmer
                scale: SAMPLES.map((t) => depthScale(phase + t * ring.dir)),
                opacity: SAMPLES.map((t) => depthOpacity(phase + t * ring.dir)),
              }}
              transition={{
                duration: ring.dur,
                ease: "linear",
                repeat: Infinity,
                times: SAMPLES,
              }}
              onClick={onSelect ? () => onSelect(sub.id) : undefined}
              title={sub.name}
              aria-label={sub.name}
            >
              <span>{sub.mark}</span>
            </motion.button>
          );
        })
      )}

      {/* central planet, breathing softly */}
      <div className="orbit-hero__core-anchor">
        <motion.div
          className="orbit-hero__core"
          animate={{ scale: [1, 1.035, 1] }}
          transition={{ duration: 5.5, ease: "easeInOut", repeat: Infinity }}
        >
          <Planet size={size * 0.3} glow flow={flow} />
        </motion.div>
      </div>
    </div>
  );
}

/* ---------------------------------------------------------------
   Orbit geometry.

   A chip's position is sampled around a tilted ellipse: the x radius
   is the full orbit radius, the y radius is flattened by SQUASH to
   suggest a plane receding into the screen, then the whole ellipse is
   rotated by the ring's tilt. Because we only ever set `x`/`y`, the
   chip itself is never scaled or sheared — it stays a clean square.
--------------------------------------------------------------- */

/** Flattening of the orbit plane. 1 = head-on circle, 0 = edge-on line. */
const SQUASH = 0.42;

/** Evenly spaced keyframe samples across one lap (0 → 1). */
const STEPS = 60;
const SAMPLES = Array.from({ length: STEPS + 1 }, (_, i) => i / STEPS);

/** Angle in radians for a normalised position around the orbit. */
function theta(t: number) {
  return (t % 1) * Math.PI * 2;
}

function ellipseX(t: number, r: number, tiltDeg: number) {
  const a = theta(t);
  const tilt = (tiltDeg * Math.PI) / 180;
  const x = Math.cos(a) * r;
  const y = Math.sin(a) * r * SQUASH;
  return x * Math.cos(tilt) - y * Math.sin(tilt);
}

function ellipseY(t: number, r: number, tiltDeg: number) {
  const a = theta(t);
  const tilt = (tiltDeg * Math.PI) / 180;
  const x = Math.cos(a) * r;
  const y = Math.sin(a) * r * SQUASH;
  return x * Math.sin(tilt) + y * Math.cos(tilt);
}

/** sin(θ) > 0 is the near side of the orbit — those chips read larger. */
function depthScale(t: number) {
  return 0.82 + 0.18 * (Math.sin(theta(t)) + 1) * 0.5 + 0.06;
}

function depthOpacity(t: number) {
  // dim while passing behind the planet
  return 0.55 + 0.45 * (Math.sin(theta(t)) + 1) * 0.5;
}

interface Star {
  x: number;
  y: number;
  r: number;
  o: number;
  delay: number;
  dur: number;
}

/** Deterministic pseudo-random field so the stars don't reshuffle on re-render. */
function makeStars(count: number, size: number): Star[] {
  let s = 9301;
  const rnd = () => {
    s = (s * 9301 + 49297) % 233280;
    return s / 233280;
  };
  return Array.from({ length: count }, () => {
    const r = 1 + rnd() * 1.8;
    return {
      x: rnd() * size,
      y: rnd() * size,
      r,
      o: 0.18 + rnd() * 0.55,
      delay: rnd() * 4,
      dur: 2.6 + rnd() * 3.4,
    };
  });
}
