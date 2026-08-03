import { useMemo, useState } from "react";
import { motion } from "framer-motion";
import { Sheet } from "@/components/ui/Sheet";
import {
  fmt,
  monthly,
  flowTotals,
  splitByFlow,
  byCategory,
} from "@/lib/money";
import type { Subscription } from "@/lib/types";
import "./breakdown.css";

type Lens = "expense" | "income";

/**
 * Tap-through breakdown for the home headline. Opens as a bottom sheet and
 * lets the user flip between an expense and an income lens, each showing:
 *   • the monthly / yearly totals + net position,
 *   • a category donut with a legend,
 *   • per-category share bars,
 *   • the biggest individual items.
 *
 * The set passed in is already scoped to the active list filter, so what the
 * user sees here matches the number they tapped exactly.
 */
export function BreakdownSheet({
  open,
  onClose,
  subs,
  currency,
  scopeLabel,
}: {
  open: boolean;
  onClose: () => void;
  subs: Subscription[];
  currency: string;
  scopeLabel: string;
}) {
  const [lens, setLens] = useState<Lens>("expense");

  const totals = useMemo(() => flowTotals(subs), [subs]);
  const { income, expense } = useMemo(() => splitByFlow(subs), [subs]);

  const set = lens === "income" ? income : expense;
  const setTotal = lens === "income" ? totals.income : totals.expense;

  const cats = useMemo(() => byCategory(set), [set]);

  // conic-gradient donut segments from the category slices
  let acc = 0;
  const stops = cats
    .map((c) => {
      const start = acc;
      acc += c.pct;
      return `${c.hue} ${start}% ${acc}%`;
    })
    .join(", ");

  const biggest = useMemo(
    () =>
      [...set]
        .sort((a, b) => monthly(b.amount, b.cycle) - monthly(a.amount, a.cycle))
        .slice(0, 4),
    [set]
  );

  const burn = totals.income > 0 ? (totals.expense / totals.income) * 100 : 0;

  return (
    <Sheet open={open} onClose={onClose}>
      <div className="bd">
        <div className="bd__head">
          <div className="bd__scope">{scopeLabel}</div>
          <h2 className="bd__title">Where your money goes</h2>
        </div>

        {/* net position headline — income vs expense at a glance */}
        <div className={"bd__net glass " + (totals.net >= 0 ? "is-up" : "is-down")}>
          <div className="bd__net-top">
            <div>
              <div className="bd__net-label">Net per month</div>
              <div className="bd__net-value tabnum">
                {totals.net < 0 ? "−" : "+"}
                {fmt(Math.abs(totals.net), currency)}
              </div>
            </div>
            <div className="bd__net-year">
              <div className="bd__net-year-label">Yearly spend</div>
              <div className="bd__net-year-value tabnum">
                {fmt(totals.expense * 12, currency)}
              </div>
            </div>
          </div>

          <div className="bd__net-bar">
            <motion.span
              className="bd__net-fill"
              initial={{ width: 0 }}
              animate={{
                width: `${
                  totals.income + totals.expense
                    ? (totals.income / (totals.income + totals.expense)) * 100
                    : 0
                }%`,
              }}
              transition={{ type: "spring", stiffness: 120, damping: 22 }}
            />
          </div>
          <div className="bd__net-legend">
            <span>
              <i className="bd__dot is-income" /> In {fmt(totals.income, currency)}
            </span>
            <span>
              <i className="bd__dot is-expense" /> Out {fmt(totals.expense, currency)}
            </span>
          </div>
          {totals.income > 0 && (
            <div className="bd__burn">
              Expenses use <b className={burn > 90 ? "is-hot" : ""}>{Math.round(burn)}%</b>{" "}
              of income
            </div>
          )}
        </div>

        {/* lens switch: expenses vs income */}
        <div className="bd__lens glass">
          {(["expense", "income"] as Lens[]).map((l) => (
            <button
              key={l}
              className={"bd__lens-btn" + (lens === l ? ` is-on is-${l}` : "")}
              onClick={() => setLens(l)}
            >
              {l === "expense" ? "Expenses" : "Income"}
            </button>
          ))}
        </div>

        {/* quick stats for the active lens */}
        <div className="bd__stats">
          <div className={"bd__stat glass is-accent is-" + lens}>
            <div className="bd__stat-label">Monthly</div>
            <div className="bd__stat-value tabnum">{fmt(setTotal, currency)}</div>
          </div>
          <div className="bd__stat glass">
            <div className="bd__stat-label">Yearly</div>
            <div className="bd__stat-value tabnum">{fmt(setTotal * 12, currency)}</div>
          </div>
          <div className="bd__stat glass">
            <div className="bd__stat-label">
              {lens === "income" ? "Sources" : "Items"}
            </div>
            <div className="bd__stat-value tabnum">{set.length}</div>
          </div>
        </div>

        {set.length === 0 ? (
          <div className="bd__empty glass">
            No {lens === "income" ? "income" : "expenses"} in {scopeLabel.toLowerCase()} yet.
          </div>
        ) : (
          <>
            {/* category donut + legend */}
            <div className="bd__section-title">By category</div>
            <div className="bd__donut-card glass">
              <div
                className="bd__donut"
                style={{ background: `conic-gradient(${stops || "#2a1e52 0% 100%"})` }}
              >
                <div className="bd__donut-hole">
                  <span className="bd__donut-total tabnum">{fmt(setTotal, currency)}</span>
                  <span className="bd__donut-lbl">/ month</span>
                </div>
              </div>
              <div className="bd__legend">
                {cats.map((c) => (
                  <div key={c.cat} className="bd__legend-row">
                    <span className="bd__legend-dot" style={{ background: c.hue }} />
                    <span className="bd__legend-name">{c.cat}</span>
                    <span className="bd__legend-pct tabnum">{Math.round(c.pct)}%</span>
                    <span className="bd__legend-amt tabnum">{fmt(c.amt, currency)}</span>
                  </div>
                ))}
              </div>
            </div>

            {/* share bars */}
            <div className="bd__bars">
              {cats.map((c, i) => (
                <div key={c.cat} className="bd__bar-row">
                  <div className="bd__bar-label">
                    <span>{c.cat}</span>
                    <b className="tabnum">{fmt(c.amt, currency)}</b>
                  </div>
                  <div className="bd__bar-track">
                    <motion.div
                      className="bd__bar-fill"
                      style={{ background: c.hue, color: c.hue }}
                      initial={{ width: 0 }}
                      animate={{ width: `${c.pct}%` }}
                      transition={{
                        delay: i * 0.045,
                        type: "spring",
                        stiffness: 120,
                        damping: 20,
                      }}
                    />
                  </div>
                </div>
              ))}
            </div>

            {/* biggest individual items */}
            <div className="bd__section-title">
              {lens === "income" ? "Biggest sources" : "Biggest costs"}
            </div>
            <div className="bd__top">
              {biggest.map((s, i) => (
                <motion.div
                  key={s.id}
                  className="bd__top-row glass"
                  initial={{ opacity: 0, y: 8 }}
                  animate={{ opacity: 1, y: 0 }}
                  transition={{ delay: i * 0.04, duration: 0.3 }}
                >
                  <span className="bd__top-logo" style={{ background: s.color }}>
                    {s.mark}
                  </span>
                  <span className="bd__top-main">
                    <span className="bd__top-name">{s.name}</span>
                    <span className="bd__top-cat">{s.category}</span>
                  </span>
                  <span
                    className={
                      "bd__top-amt tabnum " + (lens === "income" ? "amt-income" : "")
                    }
                  >
                    {fmt(monthly(s.amount, s.cycle), currency)}
                    <small>/mo</small>
                  </span>
                </motion.div>
              ))}
            </div>
          </>
        )}
      </div>
    </Sheet>
  );
}
