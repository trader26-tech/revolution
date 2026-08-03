import { useEffect, useMemo, useRef, useState } from "react";
import { AnimatePresence, motion, animate } from "framer-motion";
import { SunOrbit } from "@/components/ui/SunOrbit";
import { useStore } from "@/data/store";
import {
  fmt,
  symbol,
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
  const [period, setPeriod] = useState<"yearly" | "monthly">("yearly");
  const [listPickerOpen, setListPickerOpen] = useState(false);

  // The orbit is the hero: it fills ~60% of the viewport height, capped by
  // width so it always fits the phone, and clamped to a sensible range.
  const orbitSize = useOrbitSize();

  // Scoped by the active list only — the headline figure reads from this, so
  // the flow filter (which only narrows the "Up next" list) never changes the
  // money total shown.
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
  const headlineAmount = period === "yearly" ? totals.expense * 12 : totals.expense;

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
      <div className="home__orbit">
        <SunOrbit subs={filtered} size={orbitSize} onSelect={onOpen} />
      </div>

      {/* headline row — count + list scope on the left, spend total on the
          right. Left opens the list picker; the right figure taps to fluidly
          toggle between the yearly and monthly amount. */}
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
          onClick={() =>
            setPeriod((p) => (p === "yearly" ? "monthly" : "yearly"))
          }
          aria-label={`Showing ${period} total — tap to switch`}
          aria-live="polite"
        >
          <AnimatedMoney amount={headlineAmount} currency={currency} />
          <span className="home__hlabel home__hlabel--right">
            <span className="home__hswap">
              <AnimatePresence mode="popLayout" initial={false}>
                <motion.span
                  key={period}
                  initial={{ y: 8, opacity: 0 }}
                  animate={{ y: 0, opacity: 1 }}
                  exit={{ y: -8, opacity: 0 }}
                  transition={{ duration: 0.24, ease: [0.22, 1, 0.36, 1] }}
                >
                  {period === "yearly" ? "Total yearly" : "Per month"}
                </motion.span>
              </AnimatePresence>
            </span>
            <svg
              className={"home__hsync" + (period === "monthly" ? " is-alt" : "")}
              viewBox="0 0 24 24"
              fill="none"
              aria-hidden
            >
              <path d="M4 9a8 8 0 0 1 14-3l2 2M20 15a8 8 0 0 1-14 3l-2-2" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
              <path d="M20 4v4h-4M4 20v-4h4" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
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

/**
 * The headline money figure. When `amount` changes (the user taps to switch
 * yearly ↔ monthly) the digits roll smoothly from the old value to the new one
 * and the whole figure gives a subtle spring "pop" — so the number feels like
 * it's morphing in place rather than being swapped out.
 */
function AnimatedMoney({
  amount,
  currency,
}: {
  amount: number;
  currency: string;
}) {
  const textRef = useRef<HTMLSpanElement>(null);
  const prev = useRef(amount);
  const first = useRef(true);
  const sym = symbol(currency);
  const format = (v: number) =>
    sym + Math.round(v).toLocaleString(undefined, { maximumFractionDigits: 0 });

  useEffect(() => {
    const node = textRef.current;
    if (!node) return;

    // don't animate on the very first render — just show the value
    if (first.current) {
      first.current = false;
      prev.current = amount;
      node.textContent = format(amount);
      return;
    }

    const from = prev.current;
    prev.current = amount;

    // roll the digits from the previous figure to the new one
    const rolled = animate(from, amount, {
      duration: 0.55,
      ease: [0.22, 1, 0.36, 1],
      onUpdate: (v) => {
        node.textContent = format(v);
      },
    });
    // a quick spring "pop" on the whole figure to punctuate the switch
    const popped = animate(
      textRef.current!.parentElement!,
      { scale: [0.92, 1] },
      { type: "spring", stiffness: 520, damping: 20 }
    );
    return () => {
      rolled.stop();
      popped.stop();
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [amount]);

  return (
    <span className="home__hmoney tabnum">
      <span ref={textRef}>{format(amount)}</span>
    </span>
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

/** Sizes the orbit to ~60% of the viewport height, capped so it never exceeds
 *  the phone width, and clamped to a comfortable range. Recomputes on resize
 *  / orientation change. */
function useOrbitSize(): number {
  const compute = () => {
    if (typeof window === "undefined") return 340;
    const h = window.innerHeight;
    const w = window.innerWidth;
    // As large as possible while keeping BOTH the guide rings and the orbiting
    // planets fully on-screen. The outermost planet sits at ~0.43·size and can
    // be up to ~0.0625·size in radius, so it stays within a width w when
    //   0.4925·size ≤ w/2  →  size ≤ w/0.985.
    // We also cap by height so tall/narrow screens don't overshoot.
    const byWidth = w / 0.985;
    const target = Math.min(byWidth, h * 0.62);
    return Math.round(Math.max(300, Math.min(500, target)));
  };

  const [size, setSize] = useState(compute);

  useEffect(() => {
    const onResize = () => setSize(compute());
    window.addEventListener("resize", onResize);
    window.addEventListener("orientationchange", onResize);
    return () => {
      window.removeEventListener("resize", onResize);
      window.removeEventListener("orientationchange", onResize);
    };
  }, []);

  return size;
}
