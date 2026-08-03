import { useMemo, useState } from "react";
import { motion } from "framer-motion";
import { OrbitHero } from "@/components/ui/OrbitHero";
import { useStore } from "@/data/store";
import {
  fmt,
  flowTotals,
  nextBilling,
  daysUntil,
  relativeDay,
  cycleLabel,
  isIncome,
} from "@/lib/money";
import type { ListName, Subscription } from "@/lib/types";
import "./subscriptions.css";

const LISTS: (ListName | "All")[] = ["All", "Personal", "Family", "Business"];
type FlowFilter = "all" | "expense" | "income";

export function SubscriptionsScreen({ onOpen }: { onOpen: (id: string) => void }) {
  const { subs, currency } = useStore();
  const [list, setList] = useState<ListName | "All">("All");
  const [flowFilter, setFlowFilter] = useState<FlowFilter>("all");

  const filtered = useMemo(() => {
    let out = list === "All" ? subs : subs.filter((s) => s.list === list);
    if (flowFilter === "income") out = out.filter(isIncome);
    if (flowFilter === "expense") out = out.filter((s) => !isIncome(s));
    return out;
  }, [subs, list, flowFilter]);

  const totals = useMemo(() => flowTotals(filtered), [filtered]);

  // The planet's light follows the net position of what's on screen.
  const heroFlow = totals.net >= 0 ? "income" : "expense";

  const upcoming = useMemo(
    () =>
      [...filtered]
        .map((s) => ({ sub: s, date: nextBilling(s) }))
        .sort((a, b) => a.date.getTime() - b.date.getTime()),
    [filtered]
  );

  const trialsEnding = filtered.filter(
    (s) => s.isTrial && s.trialEnds && daysUntil(new Date(s.trialEnds + "T00:00:00")) <= 5
  );

  return (
    <div className="home">
      <header className="home__top">
        <div>
          <div className="home__hi">Your orbit</div>
          <div className="home__count">
            {filtered.length} {filtered.length === 1 ? "record" : "records"} tracked
          </div>
        </div>
        <div className="home__avatar">R</div>
      </header>

      <OrbitHero subs={filtered} size={288} flow={heroFlow} onSelect={onOpen} />

      {/* headline net position */}
      <motion.div
        className="home__total"
        initial={{ opacity: 0, y: 8 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.4, ease: [0.22, 1, 0.36, 1] }}
      >
        <div className="home__total-label">Net per month</div>
        <div
          className={
            "home__total-value tabnum " + (totals.net >= 0 ? "is-income" : "is-expense")
          }
        >
          {totals.net < 0 ? "−" : ""}
          {fmt(Math.abs(totals.net), currency)}
        </div>
        <div className="home__total-sub">
          {totals.net >= 0 ? "left over after bills" : "short each month"}
        </div>
      </motion.div>

      {/* income vs expense summary */}
      <div className="home__flows">
        <div className="home__flow glass is-income">
          <span className="home__flow-label">
            <i className="home__flow-dot" /> Income
          </span>
          <span className="home__flow-value tabnum">{fmt(totals.income, currency)}</span>
        </div>
        <div className="home__flow glass is-expense">
          <span className="home__flow-label">
            <i className="home__flow-dot" /> Expenses
          </span>
          <span className="home__flow-value tabnum">{fmt(totals.expense, currency)}</span>
        </div>
      </div>

      {trialsEnding.length > 0 && (
        <div className="home__alert glass">
          <span className="home__alert-dot" />
          {trialsEnding.length === 1
            ? `${trialsEnding[0].name} trial ends soon — cancel in time, not too late.`
            : `${trialsEnding.length} trials ending soon.`}
        </div>
      )}

      {/* flow filter */}
      <div className="home__seg glass">
        {(["all", "expense", "income"] as FlowFilter[]).map((f) => (
          <button
            key={f}
            className={"home__seg-btn" + (flowFilter === f ? ` is-on is-${f}` : "")}
            onClick={() => setFlowFilter(f)}
          >
            {f === "all" ? "All" : f === "expense" ? "Expenses" : "Income"}
          </button>
        ))}
      </div>

      {/* list filter */}
      <div className="home__filters no-scrollbar">
        {LISTS.map((l) => (
          <button
            key={l}
            className={"chip" + (list === l ? " is-on" : "")}
            onClick={() => setList(l)}
          >
            {l}
          </button>
        ))}
      </div>

      <section className="home__section">
        <div className="home__section-head">
          <h3>Up next</h3>
          <span className="home__section-note">soonest first</span>
        </div>
        <div className="home__list">
          {upcoming.map(({ sub, date }, i) => (
            <Row
              key={sub.id}
              sub={sub}
              currency={currency}
              date={date}
              index={i}
              onClick={() => onOpen(sub.id)}
            />
          ))}
          {upcoming.length === 0 && (
            <div className="home__empty glass">
              Nothing in orbit yet. Tap <b>+</b> to add income or an expense.
            </div>
          )}
        </div>
      </section>
    </div>
  );
}

function Row({
  sub,
  currency,
  date,
  index,
  onClick,
}: {
  sub: Subscription;
  currency: string;
  date: Date;
  index: number;
  onClick: () => void;
}) {
  const inDays = daysUntil(date);
  const soon = inDays <= 3;
  const income = isIncome(sub);

  return (
    <motion.button
      className={"row glass glass--tap " + (income ? "is-income" : "is-expense")}
      onClick={onClick}
      initial={{ opacity: 0, y: 8 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ delay: Math.min(index * 0.035, 0.35), duration: 0.32 }}
    >
      <span className="row__logo" style={{ background: sub.color }}>
        {sub.mark}
      </span>
      <span className="row__main">
        <span className="row__name">{sub.name}</span>
        <span className="row__meta">
          {date.toLocaleDateString(undefined, { month: "short", day: "numeric" })} ·{" "}
          {sub.category}
        </span>
      </span>
      <span className="row__right">
        <span className="row__amtline">
          <span className={"row__amt tabnum " + (income ? "amt-income" : "amt-expense")}>
            {income ? "+" : "−"}
            {fmt(sub.amount, sub.currency || currency)}
          </span>
          <span className="row__cycle">/{cycleLabel(sub.cycle)}</span>
        </span>
        <span className={"row__due" + (soon ? " is-soon" : "")}>
          {relativeDay(inDays)}
        </span>
      </span>
    </motion.button>
  );
}
