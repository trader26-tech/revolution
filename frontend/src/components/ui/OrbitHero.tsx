import { motion } from "framer-motion";
import { Planet } from "./Planet";
import type { Subscription } from "@/lib/types";
import "./orbit-hero.css";

/** The signature Orbit animation: subscription logos ride concentric rings
 *  around a central planet. Rings rotate at different speeds; each logo
 *  counter-rotates so it stays upright. */
export function OrbitHero({
  subs,
  size = 300,
}: {
  subs: Subscription[];
  size?: number;
}) {
  const items = subs.slice(0, 8);
  const rings = [
    { r: size * 0.34, dur: 26, dir: 1, chips: items.filter((_, i) => i % 2 === 0) },
    { r: size * 0.47, dur: 40, dir: -1, chips: items.filter((_, i) => i % 2 === 1) },
  ];

  return (
    <div className="orbit-hero" style={{ width: size, height: size }}>
      <div className="orbit-hero__glow" />

      {/* static ring guides */}
      {rings.map((ring, ri) => (
        <div
          key={"g" + ri}
          className="orbit-hero__guide"
          style={{ width: ring.r * 2, height: ring.r * 2 }}
        />
      ))}

      {/* rotating rings with chips — each ring is a full-size centered layer */}
      {rings.map((ring, ri) => (
        <motion.div
          key={ri}
          className="orbit-hero__ring"
          animate={{ rotate: 360 * ring.dir }}
          transition={{ duration: ring.dur, ease: "linear", repeat: Infinity }}
        >
          {ring.chips.map((sub, i) => {
            const angle = (360 / Math.max(ring.chips.length, 1)) * i;
            return (
              <div
                key={sub.id}
                className="orbit-hero__slot"
                style={{ transform: `rotate(${angle}deg) translateY(-${ring.r}px)` }}
              >
                <motion.div
                  className="orbit-hero__chip"
                  style={{ background: sub.color }}
                  animate={{ rotate: -360 * ring.dir }}
                  transition={{ duration: ring.dur, ease: "linear", repeat: Infinity }}
                >
                  <span>{sub.mark}</span>
                </motion.div>
              </div>
            );
          })}
        </motion.div>
      ))}

      {/* central planet with a soft breathing pulse */}
      <motion.div
        className="orbit-hero__core"
        animate={{ scale: [1, 1.04, 1] }}
        transition={{ duration: 4, ease: "easeInOut", repeat: Infinity }}
      >
        <Planet size={size * 0.28} glow />
      </motion.div>
    </div>
  );
}
