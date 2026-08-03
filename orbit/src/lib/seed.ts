import type { Subscription } from "./types";

/** Realistic starter data so the app feels populated on first launch.
 *  Anchor dates are relative to "today" so upcoming bills always look live. */
export function seed(): Subscription[] {
  const now = new Date();
  const iso = (offsetDays: number) => {
    const d = new Date(now);
    d.setDate(d.getDate() + offsetDays);
    return d.toISOString().slice(0, 10);
  };
  const c = (partial: Partial<Subscription> & Pick<
    Subscription,
    "name" | "color" | "mark" | "amount" | "category" | "anchorDate"
  >): Subscription => ({
    id: Math.random().toString(36).slice(2, 10),
    currency: "USD",
    cycle: "monthly",
    list: "Personal",
    paymentMethod: "Visa ···· 4242",
    createdAt: Date.now(),
    ...partial,
  });

  return [
    c({ name: "Netflix", color: "#e50914", mark: "N", amount: 15.49, category: "Streaming", anchorDate: iso(2) }),
    c({ name: "Spotify", color: "#1db954", mark: "S", amount: 10.99, category: "Music", anchorDate: iso(5) }),
    c({ name: "ChatGPT Plus", color: "#10a37f", mark: "◉", amount: 20, category: "AI", anchorDate: iso(1), list: "Business", paymentMethod: "Amex ···· 1004" }),
    c({ name: "iCloud+", color: "#3693f3", mark: "☁", amount: 2.99, category: "Cloud", anchorDate: iso(9) }),
    c({ name: "Figma", color: "#a259ff", mark: "◈", amount: 12, category: "Productivity", anchorDate: iso(14), list: "Business" }),
    c({ name: "Disney+", color: "#1f6feb", mark: "D+", amount: 139.99, category: "Streaming", anchorDate: iso(21), cycle: "yearly", list: "Family" }),
    c({ name: "Notion", color: "#2f2f2f", mark: "N", amount: 10, category: "Productivity", anchorDate: iso(-3) }),
    c({
      name: "Peloton",
      color: "#df1c2f",
      mark: "◑",
      amount: 12.99,
      category: "Fitness",
      anchorDate: iso(6),
      isTrial: true,
      trialEnds: iso(3),
    }),
  ];
}
