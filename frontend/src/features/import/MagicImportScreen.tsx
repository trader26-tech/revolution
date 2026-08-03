import { useState } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { useStore } from "@/data/store";
import { CATALOG } from "@/lib/catalog";
import type { CatalogItem } from "@/lib/types";
import "./magic.css";

interface Detected extends CatalogItem {
  chosen: boolean;
  amount: number;
}

const SAMPLE = `NETFLIX.COM            15.49
SPOTIFY P1AB2C3        10.99
AMZN Prime*2X4         14.99
FIGMA MONTHLY          12.00
OPENAI *CHATGPT        20.00
Whole Foods            62.10
Uber trip              18.40
ICLOUD+ APPLE.COM       2.99`;

/** Simulated "Magic Import": scans pasted statement / CSV text and matches
 *  known merchants from the catalog. No real OCR — pattern match on names. */
export function MagicImportScreen({ onDone }: { onDone: () => void }) {
  const { add } = useStore();
  const [text, setText] = useState("");
  const [phase, setPhase] = useState<"input" | "scanning" | "review">("input");
  const [detected, setDetected] = useState<Detected[]>([]);

  const scan = () => {
    setPhase("scanning");
    const src = (text.trim() || SAMPLE).toUpperCase();
    // small delay to sell the "magic" scan
    window.setTimeout(() => {
      const found: Detected[] = [];
      for (const c of CATALOG) {
        const key = c.name.split(" ")[0].toUpperCase().replace("+", "");
        if (src.includes(key) && !found.some((f) => f.name === c.name)) {
          // try to grab a nearby amount
          const m = src.match(
            new RegExp(key + "[^0-9]*([0-9]+\\.[0-9]{2})")
          );
          found.push({
            ...c,
            amount: m ? parseFloat(m[1]) : c.amount,
            chosen: true,
          });
        }
      }
      setDetected(found);
      setPhase("review");
    }, 1400);
  };

  const toggle = (name: string) =>
    setDetected((d) => d.map((x) => (x.name === name ? { ...x, chosen: !x.chosen } : x)));

  const importAll = () => {
    const chosen = detected.filter((d) => d.chosen);
    const today = new Date();
    chosen.forEach((c, i) => {
      const anchor = new Date(today);
      anchor.setDate(anchor.getDate() + ((i * 3 + 2) % 28));
      add({
        name: c.name,
        color: c.color,
        mark: c.mark,
        amount: c.amount,
        currency: "USD",
        cycle: "monthly",
        category: c.category,
        list: "Personal",
        paymentMethod: "Visa ···· 4242",
        anchorDate: anchor.toISOString().slice(0, 10),
      });
    });
    onDone();
  };

  return (
    <div className="magic">
      <AnimatePresence mode="wait">
        {phase === "input" && (
          <motion.div
            key="input"
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            className="magic__stage"
          >
            <p className="magic__intro">
              Paste a <b>bank statement</b>, <b>CSV</b> or card export. Magic Import
              turns it into your complete picture in seconds.
            </p>
            <textarea
              className="magic__text"
              value={text}
              onChange={(e) => setText(e.target.value)}
              placeholder={SAMPLE}
              rows={9}
            />
            <button className="magic__sample" onClick={() => setText(SAMPLE)}>
              Use sample statement
            </button>
            <button className="btn btn--primary" onClick={scan}>
              ✨ Magic Import
            </button>
          </motion.div>
        )}

        {phase === "scanning" && (
          <motion.div
            key="scan"
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            className="magic__scanning"
          >
            <div className="magic__radar">
              <span className="magic__radar-sweep" />
              <span className="magic__radar-dot" style={{ top: "22%", left: "60%" }} />
              <span className="magic__radar-dot" style={{ top: "58%", left: "30%" }} />
              <span className="magic__radar-dot" style={{ top: "70%", left: "68%" }} />
            </div>
            <div className="magic__scan-label">Scanning transactions…</div>
          </motion.div>
        )}

        {phase === "review" && (
          <motion.div
            key="review"
            initial={{ opacity: 0, y: 8 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0 }}
            className="magic__stage"
          >
            <div className="magic__found">
              Found <b>{detected.length}</b> recurring{" "}
              {detected.length === 1 ? "charge" : "charges"}
            </div>
            <div className="magic__list">
              {detected.map((d) => (
                <button
                  key={d.name}
                  className={"magic__item" + (d.chosen ? " is-on" : "")}
                  onClick={() => toggle(d.name)}
                >
                  <span className="magic__logo" style={{ background: d.color }}>
                    {d.mark}
                  </span>
                  <span className="magic__item-main">
                    <span className="magic__item-name">{d.name}</span>
                    <span className="magic__item-cat">{d.category}</span>
                  </span>
                  <span className="magic__item-amt tabnum">${d.amount.toFixed(2)}</span>
                  <span className="magic__check">
                    {d.chosen ? (
                      <svg viewBox="0 0 24 24" fill="none">
                        <path d="M5 12.5l4 4 10-10" stroke="currentColor" strokeWidth="2.4" strokeLinecap="round" strokeLinejoin="round" />
                      </svg>
                    ) : null}
                  </span>
                </button>
              ))}
              {detected.length === 0 && (
                <div className="home__empty">No known subscriptions found in that text.</div>
              )}
            </div>
            <button
              className="btn btn--primary"
              disabled={!detected.some((d) => d.chosen)}
              onClick={importAll}
            >
              Add {detected.filter((d) => d.chosen).length} to orbit
            </button>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}
