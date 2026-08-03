import type { CatalogItem } from "@/lib/types";

/** Popular services shown in the onboarding picker, with typical India (INR)
 *  monthly prices — mirrors the reference onboarding. Marks are letters/emoji
 *  so no real brand logo is reproduced. */
export const ONBOARDING_PICKS: CatalogItem[] = [
  { name: "Netflix", color: "#e50914", mark: "N", category: "Streaming", amount: 499 },
  { name: "Amazon Prime", color: "#00a8e1", mark: "a", category: "Streaming", amount: 299 },
  { name: "Disney+", color: "#1f6feb", mark: "D+", category: "Streaming", amount: 299 },
  { name: "Spotify", color: "#1db954", mark: "S", category: "Music", amount: 119 },
  { name: "YouTube Premium", color: "#ff0033", mark: "▶", category: "Streaming", amount: 149 },
  { name: "Hotstar", color: "#1f80e0", mark: "H", category: "Streaming", amount: 299 },
  { name: "Apple Music", color: "#fa233b", mark: "♪", category: "Music", amount: 99 },
  { name: "JioSaavn", color: "#2bc5b4", mark: "♫", category: "Music", amount: 99 },
  { name: "ChatGPT Plus", color: "#10a37f", mark: "◉", category: "AI", amount: 1650 },
  { name: "iCloud+", color: "#3693f3", mark: "☁", category: "Cloud", amount: 75 },
  { name: "Google One", color: "#4285f4", mark: "G", category: "Cloud", amount: 130 },
  { name: "LinkedIn Premium", color: "#0a66c2", mark: "in", category: "Productivity", amount: 1400 },
];

/** The average yearly overspend headline shown on the stat screen. */
export const OVERSPEND_INR = 120000;

/** A short, glyph-only logo strip for the welcome orbit. */
export const WELCOME_LOGOS: { mark: string; color: string }[] = [
  { mark: "N", color: "#e50914" },
  { mark: "S", color: "#1db954" },
  { mark: "▶", color: "#ff0033" },
  { mark: "a", color: "#00a8e1" },
  { mark: "◉", color: "#10a37f" },
  { mark: "☁", color: "#3693f3" },
  { mark: "G", color: "#4285f4" },
  { mark: "◈", color: "#a259ff" },
  { mark: "♪", color: "#fa233b" },
  { mark: "✳", color: "#d97757" },
];
