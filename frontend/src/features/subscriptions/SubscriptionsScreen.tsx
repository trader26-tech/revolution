import { useMemo, useState } from "react";
import { motion } from "framer-motion";
import { OrbitHero } from "@/components/ui/OrbitHero";
import { useStore } from "@/data/store";
import {
  fmt,
  totalMonthly,
  nextBilling,
  daysUntil,
  relativeDay,
  cycleLabel,
} from "@/lib/money";
import type { ListName, Subscription } from "@/lib/types";
import "./subscriptions.css";

const LISTS: (ListName | "All")[] = ["All", "Personal", "Family", "Business"];

export function SubscriptionsScreen({ onOpen }: { onOpen: (id: string) => void }) {
  const { subs, currency } = useStore();
  const [list, setList] = useState<ListName | "All">("All");

  const filtered = useMemo(
    () => (list === "All" ? subs : subs.filter((s) => s.list === list)),
    [subs, list]
  );

  const totalMo = totalMonthly(filtered);
  const totalYr = totalMo * 12;

  // upcoming, soonest first
  const upcoming = useMemo(() => {
    return [...filtered]
      .map((s) => ({ sub: s, date: nextBilling(s), in: daysUntil(nextBilling(s)) }))
      .sort((a, b) => a.date.getTime() - b.date.getTime());
  }, [filtered]);

  const trialsEnding = filtered.filter(
    (s) => s.isTrial && s.trialEnds && daysUntil(new Date(s.trialEnds + "T00:00:00")) <= 5
  );

  return (
    <div className="home">
      <header className="home__top">
        <div>
          <div className="home__hi">Your orbit</div>
          <div className="home__count">
            {filtered.length} active {filtered.length === 1 ? "subscription" : "subscriptions"}
          </div>
        </div>
        <div className="home__avatar">R</div>
      </header>

      <OrbitHero subs={filtered} size={288} />

      <motion.div
        className="home__total"
        initial={{ opacity: 0, y: 8 }}
        animate={{ opacity: 1, y: 0 }}
      >
        <div className="home__total-label">Monthly spend</div>
        <div className="home__total-value tabnum">{fmt(totalMo, currency)}</div>
        <div className="home__total-sub tabnum">{fmt(totalYr, currency)} / year</div>
      </motion.div>

      {trialsEnding.length > 0 && (
        <div className="home__alert">
          <span className="home__alert-dot" />
          {trialsEnding.length === 1
            ? `${trialsEnding[0].name} trial ends soon — cancel in time, not too late.`
            : `${trialsEnding.length} trials ending soon.`}
        </div>
      )}

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
          {upcoming.map(({ sub, date, in: inDays }) => (
            <Row
              key={sub.id}
              sub={sub}
              currency={currency}
              date={date}
              inDays={inDays}
              onClick={() => onOpen(sub.id)}
            />
          ))}
          {upcoming.length === 0 && (
            <div className="home__empty">
              Nothing in orbit yet. Tap <b>+</b> to add your first subscription.
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
  inDays,
  onClick,
}: {
  sub: Subscription;
  currency: string;
  date: Date;
  inDays: number;
  onClick: () => void;
}) {
  const soon = inDays <= 3;
  return (
    <motion.button
      className="row"
      onClick={onClick}
      whileTap={{ scale: 0.98 }}
      layout
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
        <span className="row__amt tabnum">{fmt(sub.amount, sub.currency || currency)}</span>
        <span className="row__cycle">/{cycleLabel(sub.cycle)}</span>
        <span className={"row__due" + (soon ? " is-soon" : "")}>{relativeDay(inDays)}</span>
      </span>
    </motion.button>
  );
}
