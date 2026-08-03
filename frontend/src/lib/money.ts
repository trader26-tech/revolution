import type { Cycle, Subscription } from "./types";
import { CURRENCIES, CATEGORIES } from "./catalog";

export function symbol(currency: string) {
  return CURRENCIES[currency] ?? currency + " ";
}

export function fmt(amount: number, currency = "USD") {
  const s = symbol(currency);
  const n = amount.toLocaleString(undefined, {
    minimumFractionDigits: amount % 1 === 0 ? 0 : 2,
    maximumFractionDigits: 2,
  });
  return `${s}${n}`;
}

/** Normalise any billing cycle to a monthly figure. */
export function monthly(amount: number, cycle: Cycle) {
  switch (cycle) {
    case "weekly":
      return (amount * 52) / 12;
    case "yearly":
      return amount / 12;
    default:
      return amount;
  }
}

export function yearly(amount: number, cycle: Cycle) {
  return monthly(amount, cycle) * 12;
}

export function totalMonthly(subs: Subscription[]) {
  return subs.reduce((s, x) => s + monthly(x.amount, x.cycle), 0);
}

/** Records default to "expense" when the field is absent (legacy rows). */
export function isIncome(sub: Subscription) {
  return sub.flow === "income";
}

export function splitByFlow(subs: Subscription[]) {
  const income = subs.filter(isIncome);
  const expense = subs.filter((s) => !isIncome(s));
  return { income, expense };
}

/** Monthly income, spend and the net difference for a set of records. */
export function flowTotals(subs: Subscription[]) {
  const { income, expense } = splitByFlow(subs);
  const incomeTotal = totalMonthly(income);
  const expenseTotal = totalMonthly(expense);
  return {
    income: incomeTotal,
    expense: expenseTotal,
    net: incomeTotal - expenseTotal,
  };
}

export interface CategorySlice {
  cat: string;
  amt: number;
  hue: string;
  pct: number;
}

/** Aggregate a set of records into per-category monthly slices, biggest first.
 *  `pct` is each category's share of the set total. */
export function byCategory(subs: Subscription[]): CategorySlice[] {
  const map = new Map<string, number>();
  for (const s of subs) {
    map.set(s.category, (map.get(s.category) || 0) + monthly(s.amount, s.cycle));
  }
  const total = [...map.values()].reduce((a, b) => a + b, 0);
  return [...map.entries()]
    .map(([cat, amt]) => ({
      cat,
      amt,
      hue: CATEGORIES.find((c) => c.key === cat)?.hue || "#8a1cff",
      pct: total ? (amt / total) * 100 : 0,
    }))
    .sort((a, b) => b.amt - a.amt);
}

export function cycleLabel(cycle: Cycle) {
  return cycle === "weekly" ? "wk" : cycle === "yearly" ? "yr" : "mo";
}

/** Next billing date after today given an anchor + cycle. */
export function nextBilling(sub: Subscription, from = new Date()): Date {
  const anchor = new Date(sub.anchorDate + "T00:00:00");
  const d = new Date(anchor);
  const today = new Date(from.getFullYear(), from.getMonth(), from.getDate());

  if (sub.cycle === "monthly") {
    while (d < today) d.setMonth(d.getMonth() + 1);
  } else if (sub.cycle === "yearly") {
    while (d < today) d.setFullYear(d.getFullYear() + 1);
  } else {
    while (d < today) d.setDate(d.getDate() + 7);
  }
  return d;
}

export function daysUntil(date: Date, from = new Date()) {
  const a = new Date(from.getFullYear(), from.getMonth(), from.getDate());
  const b = new Date(date.getFullYear(), date.getMonth(), date.getDate());
  return Math.round((b.getTime() - a.getTime()) / 86400000);
}

export function relativeDay(n: number) {
  if (n === 0) return "Today";
  if (n === 1) return "Tomorrow";
  if (n < 0) return `${-n}d ago`;
  if (n < 7) return `in ${n} days`;
  if (n < 30) return `in ${Math.round(n / 7)} wk`;
  return `in ${Math.round(n / 30)} mo`;
}
