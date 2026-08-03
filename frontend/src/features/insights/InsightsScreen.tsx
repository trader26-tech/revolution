import { useMemo, useState } from "react";
import { motion } from "framer-motion";
import { useStore } from "@/data/store";
import { fmt, monthly, flowTotals, splitByFlow } from "@/lib/money";
import { CATEGORIES } from "@/lib/catalog";
import type { Subscription } from "@/lib/types";
import "./insights.css";

type Lens = "expense" | "income";

export function InsightsScreen() {
  const { subs, currency } = useStore();
  const [lens, setLens] = useState<Lens>("expense");

  const totals = useMemo(() => flowTotals(subs), [subs]);
  const { income, expense } = useMemo(() => splitByFlow(subs), [subs]);

  const set = lens === "income" ? income : expense;
  const setTotal = lens === "income" ? totals.income : totals.expense;

  const byCat = useMemo(() => {
    const map = new Map<string, number>();
    for (const s of set) {
      map.set(s.category, (map.get(s.category) || 0) + monthly(s.amount, s.cycle));
    }
    return [...map.entries()]
      .map(([cat, amt]) => ({
        cat,
        amt,
        hue: CATEGORIES.find((c) => c.key === cat)?.hue || "#8a1cff",
        pct: setTotal ? (amt / setTotal) * 100 : 0,
      }))
      .sort((a, b) => b.amt - a.amt);
  }, [set, setTotal]);

  // conic-gradient donut segments
  let acc = 0;
  const stops = byCat
    .map((c) => {
      const start = acc;
      acc += c.pct;
      return `${c.hue} ${start}% ${acc}%`;
    })
    .join(", ");

  const biggest = [...set]
    .sort((a, b) => monthly(b.amount, b.cycle) - monthly(a.amount, a.cycle))
    .slice(0, 3);

  // how much of income the expenses consume
  const burn = totals.income > 0 ? (totals.expense / totals.income) * 100 : 0;

  return (
    <div className="ins">
      <header className="ins__head">
        <h2>Insights</h2>
        <div className="ins__sub">Where your money orbits</div>
      </header>

      {/* headline: net position */}
      <div
        className={
          "ins__net glass " + (totals.net >= 0 ? "is-income" : "is-expense")
        }
      >
        <div className="ins__net-label">Net per month</div>
        <div className="ins__net-value tabnum">
          {totals.net < 0 ? "−" : "+"}
          {fmt(Math.abs(totals.net), currency)}
        </div>
        <div className="ins__net-bars">
          <div className="ins__net-bar">
            <span
              className="ins__net-fill is-income"
              style={{
                width: `${
                  totals.income + totals.expense
                    ? (totals.income / (totals.income + totals.expense)) * 100
                    : 0
                }%`,
              }}
            />
          </div>
        </div>
        <div className="ins__net-legend">
          <span>
            <i className="dot is-income" /> In {fmt(totals.income, currency)}
          </span>
          <span>
            <i className="dot is-expense" /> Out {fmt(totals.expense, currency)}
          </span>
        </div>
      </div>

      {totals.income > 0 && (
        <div className="ins__burn glass">
          <span>Expenses use</span>
          <b className={burn > 90 ? "is-hot" : ""}>{Math.round(burn)}%</b>
          <span>of income</span>
        </div>
      )}

      {/* lens switch */}
      <div className="ins__lens glass">
        {(["expense", "income"] as Lens[]).map((l) => (
          <button
            key={l}
            className={"ins__lens-btn" + (lens === l ? ` is-on is-${l}` : "")}
            onClick={() => setLens(l)}
          >
            {l === "expense" ? "Expenses" : "Income"}
          </button>
        ))}
      </div>

      <div className="ins__stats">
        <Stat
          label="Monthly"
          value={fmt(setTotal, currency)}
          tone={lens}
          accent
        />
        <Stat label="Yearly" value={fmt(setTotal * 12, currency)} />
        <Stat
          label={lens === "income" ? "Sources" : "Subs"}
          value={String(set.length)}
        />
      </div>

      {set.length === 0 ? (
        <div className="ins__empty glass">
          No {lens === "income" ? "income" : "expenses"} tracked yet.
        </div>
      ) : (
        <>
          <div className="glass ins__donut-card">
            <div
              className="ins__donut"
              style={{ background: `conic-gradient(${stops || "#2a1e52 0% 100%"})` }}
            >
              <div className="ins__donut-hole">
                <span className="ins__donut-total tabnum">
                  {fmt(setTotal, currency)}
                </span>
                <span className="ins__donut-lbl">/ month</span>
              </div>
            </div>
            <div className="ins__legend">
              {byCat.map((c) => (
                <div key={c.cat} className="ins__legend-row">
                  <span className="ins__legend-dot" style={{ background: c.hue }} />
                  <span className="ins__legend-name">{c.cat}</span>
                  <span className="ins__legend-amt tabnum">
                    {fmt(c.amt, currency)}
                  </span>
                </div>
              ))}
            </div>
          </div>

          <h3 className="ins__h3">By category</h3>
          <div className="ins__bars">
            {byCat.map((c, i) => (
              <div key={c.cat} className="ins__bar-row">
                <div className="ins__bar-label">
                  <span>{c.cat}</span>
                  <b className="tabnum">{Math.round(c.pct)}%</b>
                </div>
                <div className="ins__bar-track">
                  <motion.div
                    className="ins__bar-fill"
                    style={{ background: c.hue }}
                    initial={{ width: 0 }}
                    animate={{ width: `${c.pct}%` }}
                    transition={{
                      delay: i * 0.05,
                      type: "spring",
                      stiffness: 120,
                      damping: 20,
                    }}
                  />
                </div>
              </div>
            ))}
          </div>

          <h3 className="ins__h3">
            {lens === "income" ? "Biggest sources" : "Biggest costs"}
          </h3>
          <div className="ins__top">
            {biggest.map((s: Subscription) => (
              <div key={s.id} className="ins__top-row glass">
                <span className="ins__top-logo" style={{ background: s.color }}>
                  {s.mark}
                </span>
                <span className="ins__top-name">{s.name}</span>
                <span
                  className={
                    "ins__top-amt tabnum " +
                    (lens === "income" ? "amt-income" : "")
                  }
                >
                  {fmt(monthly(s.amount, s.cycle), currency)}
                  <small>/mo</small>
                </span>
              </div>
            ))}
          </div>
        </>
      )}
    </div>
  );
}

function Stat({
  label,
  value,
  accent,
  tone,
}: {
  label: string;
  value: string;
  accent?: boolean;
  tone?: Lens;
}) {
  return (
    <div
      className={
        "ins__stat glass" +
        (accent ? " is-accent" : "") +
        (accent && tone ? ` is-${tone}` : "")
      }
    >
      <div className="ins__stat-label">{label}</div>
      <div className="ins__stat-value tabnum">{value}</div>
    </div>
  );
}
