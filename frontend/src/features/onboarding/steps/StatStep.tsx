import { motion } from "framer-motion";
import { fmt } from "@/lib/money";
import { Ghost } from "../Ghost";
import { OVERSPEND_INR } from "../data";
import { CountUp } from "../CountUp";

/** Second screen: the attention-grabbing overspend statistic, with the ghost
 *  mascot and a source line, mirroring the reference cadence. */
export function StatStep({
  onNext,
}: {
  onNext: () => void;
  onBack: () => void;
}) {
  return (
    <div className="ob-stat">
      <motion.h1
        className="ob-stat__head"
        initial={{ opacity: 0, y: 18 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.5, ease: [0.22, 1, 0.36, 1] }}
      >
        On average, we overspend{" "}
        <span className="ob-accent">
          <CountUp to={OVERSPEND_INR} format={(n) => fmt(Math.round(n), "INR")} />
        </span>{" "}
        a year on forgotten subscriptions
      </motion.h1>

      <motion.div
        className="ob-stat__ghost"
        initial={{ opacity: 0, scale: 0.7 }}
        animate={{ opacity: 1, scale: 1 }}
        transition={{ delay: 0.25, type: "spring", stiffness: 160, damping: 16 }}
      >
        <Ghost size={132} />
      </motion.div>

      <motion.p
        className="ob-stat__src"
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        transition={{ delay: 0.7, duration: 0.5 }}
      >
        Sources: C+R Research and Waterstone Survey
      </motion.p>

      <div className="ob__cta">
        <button className="ob__btn" onClick={onNext}>
          Show me an example
        </button>
      </div>
    </div>
  );
}
