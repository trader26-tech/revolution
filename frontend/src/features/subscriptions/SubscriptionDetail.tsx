import type { Subscription } from "@/lib/types";
import { fmt, monthly, yearly, nextBilling, daysUntil, relativeDay, isIncome } from "@/lib/money";
import "./detail.css";

export function SubscriptionDetail({
  sub,
  onEdit,
}: {
  sub: Subscription;
  onEdit: () => void;
}) {
  const next = nextBilling(sub);
  const inDays = daysUntil(next);
  const income = isIncome(sub);

  const facts: [string, string][] = [
    ["Billing cycle", sub.cycle[0].toUpperCase() + sub.cycle.slice(1)],
    [income ? "Per month in" : "Per month", fmt(monthly(sub.amount, sub.cycle), sub.currency)],
    [income ? "Per year in" : "Per year", fmt(yearly(sub.amount, sub.cycle), sub.currency)],
    ["Category", sub.category],
    ["List", sub.list],
    [income ? "Paid into" : "Payment", sub.paymentMethod],
  ];

  return (
    <div className={"detail " + (income ? "is-income" : "is-expense")}>
      <div
        className={"detail__hero glass " + (income ? "is-income" : "is-expense")}
        style={{ ["--c" as string]: sub.color }}
      >
        <span className={"detail__flow " + (income ? "is-income" : "is-expense")}>
          {income ? "Income" : "Expense"}
        </span>
        <span className="detail__logo" style={{ background: sub.color }}>
          {sub.mark}
        </span>
        <div className="detail__name">{sub.name}</div>
        <div className="detail__price tabnum">
          {income ? "+" : "−"}
          {fmt(sub.amount, sub.currency)}
          <span className="detail__per">
            /{sub.cycle === "yearly" ? "yr" : sub.cycle === "weekly" ? "wk" : "mo"}
          </span>
        </div>
        {sub.isTrial && <div className="detail__trial">Free trial</div>}
      </div>

      <div className="detail__next glass">
        <div>
          <div className="detail__next-label">
            {income ? "Next payout" : "Next payment"}
          </div>
          <div className="detail__next-date">
            {next.toLocaleDateString(undefined, {
              weekday: "short",
              month: "long",
              day: "numeric",
            })}
          </div>
        </div>
        <div className={"detail__next-badge" + (inDays <= 3 ? " is-soon" : "")}>
          {relativeDay(inDays)}
        </div>
      </div>

      <div className="detail__facts glass">
        {facts.map(([k, v]) => (
          <div key={k} className="detail__fact">
            <span>{k}</span>
            <b>{v}</b>
          </div>
        ))}
      </div>

      <button
        className={"btn " + (income ? "btn--income" : "btn--primary")}
        onClick={onEdit}
      >
        {income ? "Edit income" : "Edit subscription"}
      </button>
    </div>
  );
}
