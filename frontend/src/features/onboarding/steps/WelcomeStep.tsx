import type { CSSProperties } from "react";
import { motion } from "framer-motion";
import { Planet } from "@/components/ui/Planet";
import { WELCOME_LOGOS } from "../data";

/** First screen: constellation of service logos drifting around the Orbit
 *  planet, a warm welcome line, and the primary CTA. */
export function WelcomeStep({ onNext }: { onNext: () => void }) {
  return (
    <div className="ob-welcome">
      <div className="ob-welcome__sky">
        <LogoField />
      </div>

      <motion.div
        className="ob-welcome__planet"
        initial={{ scale: 0.6, opacity: 0 }}
        animate={{ scale: 1, opacity: 1 }}
        transition={{ delay: 0.15, type: "spring", stiffness: 180, damping: 18 }}
      >
        <motion.div
          animate={{ y: [0, -8, 0] }}
          transition={{ duration: 6, ease: "easeInOut", repeat: Infinity }}
        >
          <Planet size={112} glow />
        </motion.div>
      </motion.div>

      <motion.h1
        className="ob-welcome__title"
        initial={{ opacity: 0, y: 16 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ delay: 0.3, duration: 0.5, ease: [0.22, 1, 0.36, 1] }}
      >
        Welcome to Revolution
      </motion.h1>
      <motion.p
        className="ob-welcome__sub"
        initial={{ opacity: 0, y: 16 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ delay: 0.4, duration: 0.5, ease: [0.22, 1, 0.36, 1] }}
      >
        Find your subscriptions, see your spending and never miss a renewal
      </motion.p>

      <motion.div
        className="ob__cta"
        initial={{ opacity: 0, y: 22 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ delay: 0.5, duration: 0.5, ease: [0.22, 1, 0.36, 1] }}
      >
        <button className="ob__btn" onClick={onNext}>
          Start tracking
        </button>
      </motion.div>
    </div>
  );
}

/** Logos scattered on a soft grid, each drifting on its own gentle loop. */
function LogoField() {
  // Hand-placed positions (%) forming a constellation that fills the whole
  // sky top→bottom (no dead zone) and opens up in the middle so the planet
  // nests inside the cluster rather than sitting in empty space below it.
  const spots = [
    { x: 30, y: 12, d: 0.0 },
    { x: 54, y: 8, d: 0.4 },
    { x: 74, y: 16, d: 0.8 },
    { x: 16, y: 28, d: 0.6 },
    { x: 86, y: 34, d: 1.2 },
    { x: 40, y: 30, d: 0.2 },
    { x: 66, y: 40, d: 1.0 },
    { x: 12, y: 56, d: 0.9 },
    { x: 88, y: 60, d: 0.5 },
    { x: 24, y: 78, d: 1.3 },
    { x: 78, y: 82, d: 0.7 },
    { x: 50, y: 92, d: 1.5 },
  ];
  return (
    <>
      {/* two faint orbit guide rings */}
      <div className="ob-welcome__ring ob-welcome__ring--a" />
      <div className="ob-welcome__ring ob-welcome__ring--b" />
      {WELCOME_LOGOS.map((logo, i) => {
        const s = spots[i % spots.length];
        return (
          <motion.div
            key={i}
            className="ob-welcome__logo"
            style={
              { left: `${s.x}%`, top: `${s.y}%`, background: logo.color } as CSSProperties
            }
            initial={{ opacity: 0, scale: 0 }}
            animate={{
              opacity: 1,
              scale: 1,
              y: [0, -6, 0],
            }}
            transition={{
              opacity: { delay: 0.1 + i * 0.05, duration: 0.4 },
              scale: {
                delay: 0.1 + i * 0.05,
                type: "spring",
                stiffness: 200,
                damping: 14,
              },
              y: {
                duration: 3.5 + s.d,
                ease: "easeInOut",
                repeat: Infinity,
                delay: s.d,
              },
            }}
          >
            <span>{logo.mark}</span>
          </motion.div>
        );
      })}
    </>
  );
}
