import { useMemo } from "react";
import { motion } from "framer-motion";
import { useStore } from "../lib/store";
import { fmt, monthly, totalMonthly } from "../lib/money";
import { CATEGORIES } from "../lib/catalog";
import "./insights.css";

export function Insights() {
  const { subs, currency } = useStore();
  const totalMo = totalMonthly(subs);

  const byCat = useMemo(() => {
    const map = new Map<string, number>();
    for (const s of subs) {
      map.set(s.category, (map.get(s.category) || 0) + monthly(s.amount, s.cycle));
    }
    return [...map.entries()]
      .map(([cat, amt]) => ({
        cat,
        amt,
        hue: CATEGORIES.find((c) => c.key === cat)?.hue || "#8a1cff",
        pct: totalMo ? (amt / totalMo) * 100 : 0,
      }))
      .sort((a, b) => b.amt - a.amt);
  }, [subs, totalMo]);

  // conic-gradient donut segments
  let acc = 0;
  const stops = byCat
    .map((c) => {
      const start = acc;
      acc += c.pct;
      return `${c.hue} ${start}% ${acc}%`;
    })
    .join(", ");

  const priciest = [...subs].sort((a, b) => monthly(b.amount, b.cycle) - monthly(a.amount, a.cycle)).slice(0, 3);
  const avg = subs.length ? totalMo / subs.length : 0;

  return (
    <div className="ins">
      <header className="ins__head">
        <h2>Insights</h2>
        <div className="ins__sub">Where your money orbits</div>
      </header>

      <div className="ins__stats">
        <Stat label="Monthly" value={fmt(totalMo, currency)} accent />
        <Stat label="Yearly" value={fmt(totalMo * 12, currency)} />
        <Stat label="Avg / sub" value={fmt(avg, currency)} />
      </div>

      <div className="card ins__donut-card">
        <div
          className="ins__donut"
          style={{ background: `conic-gradient(${stops || "#2a1e52 0% 100%"})` }}
        >
          <div className="ins__donut-hole">
            <span className="ins__donut-total tabnum">{fmt(totalMo, currency)}</span>
            <span className="ins__donut-lbl">/ month</span>
          </div>
        </div>
        <div className="ins__legend">
          {byCat.map((c) => (
            <div key={c.cat} className="ins__legend-row">
              <span className="ins__legend-dot" style={{ background: c.hue }} />
              <span className="ins__legend-name">{c.cat}</span>
              <span className="ins__legend-amt tabnum">{fmt(c.amt, currency)}</span>
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
                transition={{ delay: i * 0.05, type: "spring", stiffness: 120, damping: 20 }}
              />
            </div>
          </div>
        ))}
      </div>

      <h3 className="ins__h3">Biggest costs</h3>
      <div className="ins__top">
        {priciest.map((s) => (
          <div key={s.id} className="ins__top-row">
            <span className="ins__top-logo" style={{ background: s.color }}>{s.mark}</span>
            <span className="ins__top-name">{s.name}</span>
            <span className="ins__top-amt tabnum">
              {fmt(monthly(s.amount, s.cycle), currency)}<small>/mo</small>
            </span>
          </div>
        ))}
      </div>
    </div>
  );
}

function Stat({ label, value, accent }: { label: string; value: string; accent?: boolean }) {
  return (
    <div className={"ins__stat" + (accent ? " is-accent" : "")}>
      <div className="ins__stat-label">{label}</div>
      <div className="ins__stat-value tabnum">{value}</div>
    </div>
  );
}
