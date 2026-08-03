import { motion } from "framer-motion";
import type { CatalogItem } from "@/lib/types";
import { fmt } from "@/lib/money";

interface Props {
  currency: string;
  options: CatalogItem[];
  chosen: CatalogItem[];
  onChange: (next: CatalogItem[]) => void;
  onNext: () => void;
  onSkip: () => void;
}

/** Third screen: pick the subscriptions you pay for. Multi-select rows with a
 *  logo, name and typical price. Footer CTA reflects the current selection. */
export function PickStep({
  currency,
  options,
  chosen,
  onChange,
  onNext,
  onSkip,
}: Props) {
  const isOn = (o: CatalogItem) => chosen.some((c) => c.name === o.name);

  const toggle = (o: CatalogItem) => {
    onChange(isOn(o) ? chosen.filter((c) => c.name !== o.name) : [...chosen, o]);
  };

  const count = chosen.length;

  return (
    <div className="ob-pick">
      <div className="ob-pick__top">
        <button className="ob-pick__skip glass glass--tap" onClick={onSkip}>
          Skip
        </button>
      </div>

      <motion.h1
        className="ob-pick__title"
        initial={{ opacity: 0, y: 14 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.45, ease: [0.22, 1, 0.36, 1] }}
      >
        Which subscriptions do you pay for?
      </motion.h1>
      <p className="ob-pick__hint">Typical monthly price, you can edit later.</p>

      <div className="ob-pick__list no-scrollbar">
        {options.map((o, i) => {
          const on = isOn(o);
          return (
            <motion.button
              key={o.name}
              className={"ob-pick__row glass glass--tap" + (on ? " is-on" : "")}
              onClick={() => toggle(o)}
              initial={{ opacity: 0, y: 12 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{
                delay: 0.05 + i * 0.03,
                duration: 0.4,
                ease: [0.22, 1, 0.36, 1],
              }}
            >
              <span className={"ob-pick__check" + (on ? " is-on" : "")}>
                {on && (
                  <motion.svg
                    viewBox="0 0 24 24"
                    width="14"
                    height="14"
                    initial={{ scale: 0 }}
                    animate={{ scale: 1 }}
                    transition={{ type: "spring", stiffness: 500, damping: 20 }}
                  >
                    <path
                      d="M5 13l4 4L19 7"
                      fill="none"
                      stroke="#fff"
                      strokeWidth="3"
                      strokeLinecap="round"
                      strokeLinejoin="round"
                    />
                  </motion.svg>
                )}
              </span>

              <span className="ob-pick__logo" style={{ background: o.color }}>
                {o.mark}
              </span>
              <span className="ob-pick__name">{o.name}</span>
              <span className="ob-pick__price tabnum">
                {fmt(o.amount, currency)}
              </span>
            </motion.button>
          );
        })}
      </div>

      <div className="ob__cta">
        <button className="ob__btn" onClick={onNext}>
          {count === 0
            ? "None of these"
            : `Add ${count} subscription${count > 1 ? "s" : ""}`}
        </button>
      </div>
    </div>
  );
}
