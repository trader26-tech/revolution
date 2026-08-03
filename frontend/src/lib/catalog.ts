import type { CatalogItem } from "./types";

/** A small catalog of popular services for the "add subscription" picker.
 *  Marks are letters/emoji so nothing is copied from a brand's real logo. */
export const CATALOG: CatalogItem[] = [
  { name: "Netflix", color: "#e50914", mark: "N", category: "Streaming", amount: 15.49 },
  { name: "Spotify", color: "#1db954", mark: "S", category: "Music", amount: 10.99 },
  { name: "Disney+", color: "#1f6feb", mark: "D+", category: "Streaming", amount: 13.99 },
  { name: "YouTube Premium", color: "#ff0033", mark: "▶", category: "Streaming", amount: 13.99 },
  { name: "Amazon Prime", color: "#00a8e1", mark: "a", category: "Streaming", amount: 14.99 },
  { name: "Apple Music", color: "#fa233b", mark: "♪", category: "Music", amount: 10.99 },
  { name: "iCloud+", color: "#3693f3", mark: "☁", category: "Cloud", amount: 2.99 },
  { name: "Google One", color: "#4285f4", mark: "G", category: "Cloud", amount: 1.99 },
  { name: "Dropbox", color: "#0061ff", mark: "▱", category: "Cloud", amount: 11.99 },
  { name: "Notion", color: "#111111", mark: "N", category: "Productivity", amount: 10 },
  { name: "Figma", color: "#a259ff", mark: "◈", category: "Productivity", amount: 12 },
  { name: "Adobe CC", color: "#fa0f00", mark: "Ai", category: "Productivity", amount: 59.99 },
  { name: "ChatGPT Plus", color: "#10a37f", mark: "◉", category: "AI", amount: 20 },
  { name: "Claude Pro", color: "#d97757", mark: "✳", category: "AI", amount: 20 },
  { name: "Midjourney", color: "#4b4bff", mark: "⛵", category: "AI", amount: 10 },
  { name: "iCloud Storage", color: "#3693f3", mark: "☁", category: "Cloud", amount: 0.99 },
  { name: "Xbox Game Pass", color: "#107c10", mark: "✕", category: "Gaming", amount: 16.99 },
  { name: "PlayStation Plus", color: "#0070d1", mark: "P", category: "Gaming", amount: 17.99 },
  { name: "Nintendo Online", color: "#e60012", mark: "◕", category: "Gaming", amount: 3.99 },
  { name: "The Times", color: "#1a1a1a", mark: "T", category: "News", amount: 8 },
  { name: "NYTimes", color: "#000000", mark: "𝕋", category: "News", amount: 17 },
  { name: "Medium", color: "#1a8917", mark: "M", category: "News", amount: 5 },
  { name: "Peloton", color: "#df1c2f", mark: "◑", category: "Fitness", amount: 12.99 },
  { name: "Strava", color: "#fc4c02", mark: "≈", category: "Fitness", amount: 11.99 },
  { name: "Audible", color: "#f8991c", mark: "◠", category: "Streaming", amount: 14.95 },
  { name: "HBO Max", color: "#7b2ff7", mark: "H", category: "Streaming", amount: 15.99 },
  { name: "1Password", color: "#1a6ce7", mark: "🔑", category: "Utilities", amount: 2.99 },
  { name: "GitHub Pro", color: "#24292f", mark: "⌘", category: "Productivity", amount: 4 },
];

/** Recurring money coming *in*. Shown under the Income tab of the picker. */
export const INCOME_CATALOG: CatalogItem[] = [
  { name: "Salary", color: "#16a34a", mark: "₩", category: "Salary", amount: 4200, flow: "income" },
  { name: "Freelance", color: "#0ea5e9", mark: "◆", category: "Freelance", amount: 800, flow: "income" },
  { name: "Dividends", color: "#22c55e", mark: "▲", category: "Dividends", amount: 120, flow: "income" },
  { name: "Rental income", color: "#14b8a6", mark: "⌂", category: "Rental", amount: 950, flow: "income" },
  { name: "Refunds", color: "#84cc16", mark: "↺", category: "Refunds", amount: 40, flow: "income" },
  { name: "Interest", color: "#10b981", mark: "%", category: "Dividends", amount: 25, flow: "income" },
];

export const CATEGORIES: { key: string; label: string; hue: string }[] = [
  { key: "Streaming", label: "Streaming", hue: "#ff2d78" },
  { key: "Music", label: "Music", hue: "#37e0a6" },
  { key: "Productivity", label: "Productivity", hue: "#8a1cff" },
  { key: "Cloud", label: "Cloud", hue: "#3693f3" },
  { key: "AI", label: "AI", hue: "#a855ff" },
  { key: "Gaming", label: "Gaming", hue: "#ffb020" },
  { key: "Fitness", label: "Fitness", hue: "#ff6a2b" },
  { key: "News", label: "News", hue: "#67e8f9" },
  { key: "Utilities", label: "Utilities", hue: "#94a3b8" },
  { key: "Other", label: "Other", hue: "#c4b5fd" },
  { key: "Salary", label: "Salary", hue: "#16a34a" },
  { key: "Freelance", label: "Freelance", hue: "#0ea5e9" },
  { key: "Dividends", label: "Dividends", hue: "#22c55e" },
  { key: "Rental", label: "Rental", hue: "#14b8a6" },
  { key: "Refunds", label: "Refunds", hue: "#84cc16" },
];

/** Light colours cast onto a planet by flow direction. */
export const FLOW_LIGHT = {
  income: { key: "#7cf7b0", warm: "#2fe08a", glow: "rgba(55,224,166,0.55)" },
  expense: { key: "#ff9db0", warm: "#ff4d6d", glow: "rgba(255,77,109,0.5)" },
} as const;

export const CURRENCIES: Record<string, string> = {
  USD: "$",
  EUR: "€",
  GBP: "£",
  INR: "₹",
  JPY: "¥",
  AUD: "A$",
  CAD: "C$",
};

export const PAYMENT_METHODS = [
  "Visa ···· 4242",
  "Mastercard ···· 8210",
  "Apple Pay",
  "PayPal",
  "Amex ···· 1004",
];
