export type Cycle = "weekly" | "monthly" | "yearly";
export type ListName = "Personal" | "Family" | "Business";

/** Direction of money. Drives the colour of the light falling on a planet:
 *  income catches a soft green highlight, expense a soft red one. */
export type Flow = "income" | "expense";
export type Category =
  | "Streaming"
  | "Music"
  | "Productivity"
  | "Cloud"
  | "Fitness"
  | "Gaming"
  | "News"
  | "AI"
  | "Utilities"
  | "Other"
  // income-side categories
  | "Salary"
  | "Freelance"
  | "Dividends"
  | "Rental"
  | "Refunds";

export interface Subscription {
  id: string;
  name: string;
  /** hex color for the tile */
  color: string;
  /** short mark shown in the logo chip (1–2 letters or emoji) */
  mark: string;
  amount: number;
  currency: string;
  cycle: Cycle;
  category: Category;
  list: ListName;
  /** Money in or money out. Defaults to "expense" for legacy records. */
  flow?: Flow;
  paymentMethod: string;
  /** ISO date the plan first billed / next anchor */
  anchorDate: string;
  isTrial?: boolean;
  /** trial end ISO date */
  trialEnds?: string;
  notes?: string;
  createdAt: number;
}

export interface CatalogItem {
  name: string;
  color: string;
  mark: string;
  category: Category;
  amount: number;
  flow?: Flow;
}
