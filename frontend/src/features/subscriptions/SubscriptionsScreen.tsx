import { memo, useEffect, useMemo, useState } from "react";
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

/** Rows rendered in "Up next" before the user asks for more. Rendering is the
 *  cost with big data sets — the maths is trivial — so the DOM is capped and
 *  grows only on demand. */
const LIST_PAGE = 15;

export function SubscriptionsScreen({
  onOpen,
  onAdd,
}: {
  onOpen: (id: string) => void;
  onAdd: () => void;
}) {
  const { subs, currency } = useStore();
  const [list, setList] = useState<ListName | "All">("All");
  const [flowFilter, setFlowFilter] = useState<FlowFilter>("all");
  const [period, setPeriod] = useState<"yearly" | "monthly">("yearly");
  const [listPickerOpen, setListPickerOpen] = useState(false);
  const [visibleRows, setVisibleRows] = useState(LIST_PAGE);

  const orbitSize = useOrbitSize();

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

  // collapse the list again whenever the data scope changes
  useEffect(() => setVisibleRows(LIST_PAGE), [list, flowFilter]);
  const shown = upcoming.slice(0, visibleRows);
  const hiddenCount = upcoming.length - shown.length;

  const trialsEnding = useMemo(
    () =>
      filtered.filter(
        (s) =>
          s.isTrial &&
          s.trialEnds &&
          daysUntil(new Date(s.trialEnds + "T00:00:00")) <= 5
      ),
    [filtered]
  );

  return (
    <div className="home">
      {/* floating add button, top-right corner */}
      <button className="home__add" onClick={onAdd} aria-label="Add subscription">
        <svg viewBox="0 0 24 24" width="22" height="22" fill="none" aria-hidden>
          <path d="M12 5v14M5 12h14" stroke="currentColor" strokeWidth="2.4" strokeLinecap="round" />
        </svg>
      </button>

      <div className="home__orbit">
        <SunOrbit subs={filtered} size={orbitSize} onSelect={onOpen} />
      </div>

      {/* headline row — count + list scope left, spend total right */}
      <div className="home__headline">
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
          onClick={() => setPeriod((p) => (p === "yearly" ? "monthly" : "yearly"))}
          aria-label={`Showing ${period} total — tap to switch`}
          aria-live="polite"
        >
          <span className="home__hmoney tabnum">
            {formatMoney(headlineAmount, currency)}
          </span>
          <span className="home__hlabel home__hlabel--right">
            <span>{period === "yearly" ? "Total yearly" : "Per month"}</span>
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
      </div>

      {/* list scope picker */}
      {listPickerOpen && (
        <>
          <div
            className="home__pick-scrim"
            onClick={() => setListPickerOpen(false)}
          />
          <div className="home__pick glass glass--strong">
            {LISTS.map((l) => {
              const count =
                l === "All" ? subs.length : subs.filter((s) => s.list === l).length;
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
          </div>
        </>
      )}

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
          {shown.map(({ sub, date }) => (
            <Row
              key={sub.id}
              sub={sub}
              currency={currency}
              date={date}
              onOpen={onOpen}
            />
          ))}
          {hiddenCount > 0 && (
            <button
              className="home__more glass glass--tap"
              onClick={() => setVisibleRows((v) => v + 50)}
            >
              Show more ({hiddenCount} remaining)
            </button>
          )}
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

/** Headline money: compact above a million so it always fits the screen. */
function formatMoney(amount: number, currency: string) {
  const sym = symbol(currency);
  const n = Math.round(amount);
  if (Math.abs(n) >= 1_000_000) {
    return (
      sym +
      new Intl.NumberFormat(undefined, {
        notation: "compact",
        maximumFractionDigits: 1,
      }).format(n)
    );
  }
  return sym + n.toLocaleString(undefined, { maximumFractionDigits: 0 });
}

/** One "Up next" row. Memoised: with a long list, a state change re-renders
 *  only what actually changed instead of every row. */
const Row = memo(function Row({
  sub,
  currency,
  date,
  onOpen,
}: {
  sub: Subscription;
  currency: string;
  date: Date;
  onOpen: (id: string) => void;
}) {
  const inDays = daysUntil(date);
  const soon = inDays <= 3;
  const income = isIncome(sub);

  return (
    <button
      className={"row glass glass--tap " + (income ? "is-income" : "is-expense")}
      onClick={() => onOpen(sub.id)}
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
    </button>
  );
});

/** Sizes the orbit to ~60% of the viewport height, capped by width. */
function useOrbitSize(): number {
  const compute = () => {
    if (typeof window === "undefined") return 340;
    const h = window.innerHeight;
    const w = window.innerWidth;
    const byWidth = w - 8;
    const target = Math.min(byWidth, h * 0.6);
    return Math.round(Math.max(280, Math.min(480, target)));
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
