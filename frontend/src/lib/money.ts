import type { Cycle, Subscription } from "./types";
import { CURRENCIES } from "./catalog";

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
