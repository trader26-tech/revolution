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
  // hand-placed positions (%) so the composition reads like the reference
  const spots = [
    { x: 28, y: 30, d: 0 },
    { x: 52, y: 18, d: 0.4 },
    { x: 70, y: 26, d: 0.8 },
    { x: 82, y: 42, d: 1.2 },
    { x: 16, y: 46, d: 0.6 },
    { x: 34, y: 54, d: 1.0 },
    { x: 48, y: 44, d: 0.2 },
    { x: 64, y: 58, d: 1.4 },
    { x: 26, y: 70, d: 0.9 },
    { x: 76, y: 66, d: 0.5 },
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
