import { motion } from "framer-motion";
import { fmt, yearly } from "@/lib/money";
import { Ghost } from "../Ghost";
import { CountUp } from "../CountUp";
import type { NewSub } from "../Onboarding";

/** Fourth screen: reveal the yearly total of the chosen subscriptions, then a
 *  reflective prompt and the final CTA that drops the user into the app. */
export function RevealStep({
  currency,
  picks,
  onFinish,
}: {
  currency: string;
  picks: NewSub[];
  onFinish: () => void;
}) {
  const total = picks.reduce((s, p) => s + yearly(p.amount, p.cycle), 0);

  return (
    <div className="ob-reveal">
      <motion.div
        className="ob-reveal__amount"
        initial={{ opacity: 0, y: 18 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.5, ease: [0.22, 1, 0.36, 1] }}
      >
        That’s{" "}
        <span className="ob-accent">
          <CountUp to={total} format={(n) => fmt(Math.round(n), currency)} />
        </span>{" "}
        a year
      </motion.div>

      <motion.h1
        className="ob-reveal__q"
        initial={{ opacity: 0, y: 18 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ delay: 0.25, duration: 0.5, ease: [0.22, 1, 0.36, 1] }}
      >
        How many others are you paying for quietly in the background?
      </motion.h1>

      <motion.div
        className="ob-reveal__ghost"
        initial={{ opacity: 0, scale: 0.7 }}
        animate={{ opacity: 1, scale: 1 }}
        transition={{ delay: 0.4, type: "spring", stiffness: 160, damping: 16 }}
      >
        <Ghost size={120} />
      </motion.div>

      <div className="ob__cta">
        <button className="ob__btn" onClick={onFinish}>
          Continue
        </button>
      </div>
    </div>
  );
}
