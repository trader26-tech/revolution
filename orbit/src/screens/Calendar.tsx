import { useMemo, useState } from "react";
import { motion } from "framer-motion";
import { useStore } from "../lib/store";
import { fmt, nextBilling } from "../lib/money";
import "./calendar.css";

const WD = ["M", "T", "W", "T", "F", "S", "S"];

export function Calendar({ onOpen }: { onOpen: (id: string) => void }) {
  const { subs, currency } = useStore();
  const today = new Date();
  const [month, setMonth] = useState(new Date(today.getFullYear(), today.getMonth(), 1));

  // map: day-of-month -> subs billing that day this month
  const billing = useMemo(() => {
    const map = new Map<number, typeof subs>();
    for (const s of subs) {
      // find the occurrence within this displayed month
      const d = nextBilling(s, new Date(month.getFullYear(), month.getMonth(), 1));
      if (d.getMonth() === month.getMonth() && d.getFullYear() === month.getFullYear()) {
        const day = d.getDate();
        map.set(day, [...(map.get(day) || []), s]);
      }
    }
    return map;
  }, [subs, month]);

  const first = new Date(month.getFullYear(), month.getMonth(), 1);
  const startPad = (first.getDay() + 6) % 7; // Monday-first
  const daysInMonth = new Date(month.getFullYear(), month.getMonth() + 1, 0).getDate();
  const cells: (number | null)[] = [
    ...Array(startPad).fill(null),
    ...Array.from({ length: daysInMonth }, (_, i) => i + 1),
  ];

  const monthTotal = subs.reduce((s, x) => {
    const d = nextBilling(x, first);
    return d.getMonth() === month.getMonth() && d.getFullYear() === month.getFullYear()
      ? s + x.amount
      : s;
  }, 0);

  const step = (dir: number) =>
    setMonth((m) => new Date(m.getFullYear(), m.getMonth() + dir, 1));

  const isToday = (day: number) =>
    today.getDate() === day &&
    today.getMonth() === month.getMonth() &&
    today.getFullYear() === month.getFullYear();

  // upcoming list for the month
  const list = useMemo(() => {
    const rows: { day: number; sub: (typeof subs)[number] }[] = [];
    for (const [day, arr] of billing) for (const sub of arr) rows.push({ day, sub });
    return rows.sort((a, b) => a.day - b.day);
  }, [billing]);

  return (
    <div className="cal">
      <header className="cal__head">
        <div>
          <h2>Calendar</h2>
          <div className="cal__sub tabnum">
            {fmt(monthTotal, currency)} due in{" "}
            {month.toLocaleDateString(undefined, { month: "long" })}
          </div>
        </div>
        <div className="cal__nav">
          <button onClick={() => step(-1)} aria-label="Previous month">‹</button>
          <span className="cal__month">
            {month.toLocaleDateString(undefined, { month: "short", year: "numeric" })}
          </span>
          <button onClick={() => step(1)} aria-label="Next month">›</button>
        </div>
      </header>

      <div className="cal__grid">
        {WD.map((d, i) => (
          <div key={i} className="cal__wd">{d}</div>
        ))}
        {cells.map((day, i) => {
          const arr = day ? billing.get(day) : undefined;
          return (
            <div
              key={i}
              className={
                "cal__cell" +
                (day && isToday(day) ? " is-today" : "") +
                (arr ? " has" : "") +
                (!day ? " empty" : "")
              }
            >
              {day && <span className="cal__num">{day}</span>}
              {arr && (
                <span className="cal__dots">
                  {arr.slice(0, 3).map((s) => (
                    <span key={s.id} className="cal__dot" style={{ background: s.color }} />
                  ))}
                </span>
              )}
            </div>
          );
        })}
      </div>

      <div className="cal__list">
        {list.map(({ day, sub }, i) => (
          <motion.button
            key={sub.id + day}
            className="cal__row"
            initial={{ opacity: 0, x: -6 }}
            animate={{ opacity: 1, x: 0 }}
            transition={{ delay: Math.min(i * 0.03, 0.3) }}
            onClick={() => onOpen(sub.id)}
          >
            <span className="cal__row-date">
              <b>{day}</b>
              <span>{month.toLocaleDateString(undefined, { month: "short" })}</span>
            </span>
            <span className="cal__row-logo" style={{ background: sub.color }}>{sub.mark}</span>
            <span className="cal__row-name">{sub.name}</span>
            <span className="cal__row-amt tabnum">{fmt(sub.amount, sub.currency || currency)}</span>
          </motion.button>
        ))}
        {list.length === 0 && (
          <div className="home__empty">No payments this month.</div>
        )}
      </div>
    </div>
  );
}
