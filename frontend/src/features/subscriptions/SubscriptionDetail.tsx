import type { Subscription } from "@/lib/types";
import { fmt, monthly, yearly, nextBilling, daysUntil, relativeDay } from "@/lib/money";
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

  const facts: [string, string][] = [
    ["Billing cycle", sub.cycle[0].toUpperCase() + sub.cycle.slice(1)],
    ["Per month", fmt(monthly(sub.amount, sub.cycle), sub.currency)],
    ["Per year", fmt(yearly(sub.amount, sub.cycle), sub.currency)],
    ["Category", sub.category],
    ["List", sub.list],
    ["Payment", sub.paymentMethod],
  ];

  return (
    <div className="detail">
      <div className="detail__hero" style={{ ["--c" as string]: sub.color }}>
        <span className="detail__logo" style={{ background: sub.color }}>
          {sub.mark}
        </span>
        <div className="detail__name">{sub.name}</div>
        <div className="detail__price tabnum">
          {fmt(sub.amount, sub.currency)}
          <span className="detail__per">
            /{sub.cycle === "yearly" ? "yr" : sub.cycle === "weekly" ? "wk" : "mo"}
          </span>
        </div>
        {sub.isTrial && <div className="detail__trial">Free trial</div>}
      </div>

      <div className="detail__next">
        <div>
          <div className="detail__next-label">Next payment</div>
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

      <div className="detail__facts">
        {facts.map(([k, v]) => (
          <div key={k} className="detail__fact">
            <span>{k}</span>
            <b>{v}</b>
          </div>
        ))}
      </div>

      <button className="btn btn--primary" onClick={onEdit}>
        Edit subscription
      </button>
    </div>
  );
}
