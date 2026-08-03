import { useMemo, useState } from "react";
import { AnimatePresence, motion } from "framer-motion";
import { SunOrbit } from "@/components/ui/SunOrbit";
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
import { BreakdownSheet } from "./BreakdownSheet";
import "./subscriptions.css";

const LISTS: (ListName | "All")[] = ["All", "Personal", "Family", "Business"];
type FlowFilter = "all" | "expense" | "income";

export function SubscriptionsScreen({ onOpen }: { onOpen: (id: string) => void }) {
  const { subs, currency } = useStore();
  const [list, setList] = useState<ListName | "All">("All");
  const [flowFilter, setFlowFilter] = useState<FlowFilter>("all");
  const [breakdownOpen, setBreakdownOpen] = useState(false);
  const [listPickerOpen, setListPickerOpen] = useState(false);

  // Scoped by the active list only — the breakdown sheet and the headline
  // figures both read from this, so the flow filter (which only narrows the
  // "Up next" list) never changes the money totals the user tapped.
  const scoped = useMemo(
    () => (list === "All" ? subs : subs.filter((s) => s.list === list)),
    [subs, list]
  );

  const filtered = useMemo(() => {
    let out = scoped;
    if (flowFilter === "income") out = out.filter(isIncome);
    if (flowFilter === "expense") out = out.filter((s) => !isIncome(s));
    return out;
  }, [scoped, flowFilter]);

  const totals = useMemo(() => flowTotals(scoped), [scoped]);
  const yearlySpend = totals.expense * 12;

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

      <div className="home__orbit">
        <SunOrbit subs={filtered} size={272} onSelect={onOpen} />
      </div>

      {/* headline row — count + list scope on the left, yearly spend on the
          right. Both halves are tappable: left opens the list picker, right
          opens the money breakdown. */}
      <motion.div
        className="home__headline"
        initial={{ opacity: 0, y: 8 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.4, ease: [0.22, 1, 0.36, 1] }}
      >
        <button
          className="home__hcell home__hcell--left"
          onClick={() => setListPickerOpen(true)}
          aria-label="Change list"
        >
          <span className="home__hnum tabnum">{scoped.length}</span>
          <span className="home__hlabel">
            {list === "All" ? "All" : list}
            <svg className="home__hchev" viewBox="0 0 24 24" fill="none" aria-hidden>
              <path d="M8 9l4-4 4 4M8 15l4 4 4-4" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
            </svg>
          </span>
        </button>

        <button
          className="home__hcell home__hcell--right"
          onClick={() => setBreakdownOpen(true)}
          aria-label="See money breakdown"
        >
          <span className="home__hmoney tabnum">{fmt(yearlySpend, currency)}</span>
          <span className="home__hlabel home__hlabel--right">
            Total yearly
            <svg className="home__hgo" viewBox="0 0 24 24" fill="none" aria-hidden>
              <path d="M9 6l6 6-6 6" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
            </svg>
          </span>
        </button>
      </motion.div>

      {/* list scope picker */}
      <AnimatePresence>
        {listPickerOpen && (
          <>
            <motion.div
              className="home__pick-scrim"
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0 }}
              onClick={() => setListPickerOpen(false)}
            />
            <motion.div
              className="home__pick glass glass--strong"
              initial={{ opacity: 0, y: -6, scale: 0.96 }}
              animate={{ opacity: 1, y: 0, scale: 1 }}
              exit={{ opacity: 0, y: -6, scale: 0.96 }}
              transition={{ type: "spring", stiffness: 420, damping: 30 }}
            >
              {LISTS.map((l) => {
                const count =
                  l === "All"
                    ? subs.length
                    : subs.filter((s) => s.list === l).length;
                return (
                  <button
                    key={l}
                    className={"home__pick-item" + (list === l ? " is-on" : "")}
                    onClick={() => {
                      setList(l);
                      setListPickerOpen(false);
                    }}
                  >
                    <span>{l}</span>
                    <span className="home__pick-count tabnum">{count}</span>
                  </button>
                );
              })}
            </motion.div>
          </>
        )}
      </AnimatePresence>

      <BreakdownSheet
        open={breakdownOpen}
        onClose={() => setBreakdownOpen(false)}
        subs={scoped}
        currency={currency}
        scopeLabel={list === "All" ? "All records" : list}
      />

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
