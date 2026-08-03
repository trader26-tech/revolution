import type { CatalogItem } from "./types";
import { BRANDS } from "./brands.generated";

/** Typical monthly prices (USD) for well-known services, so the picker
 *  pre-fills a sensible amount. Anything not listed defaults to 9.99. */
const TYPICAL_PRICE: Record<string, number> = {
  Netflix: 15.49, "Disney+": 13.99, "Prime Video": 8.99, YouTube: 13.99,
  "HBO Max": 15.99, Max: 15.99, Hulu: 17.99, "Paramount+": 11.99,
  "Apple TV+": 9.99, Crunchyroll: 7.99, Twitch: 8.99, Vimeo: 12, Audible: 14.95,
  Spotify: 11.99, "Apple Music": 10.99, Tidal: 10.99, Deezer: 11.99,
  SoundCloud: 12, Bandcamp: 10, Pandora: 9.99,
  iCloud: 2.99, "Google Drive": 1.99, Dropbox: 11.99, "Google One": 1.99,
  "Proton Drive": 3.99, pCloud: 4.99, Mega: 5.99,
  Notion: 10, Figma: 12, Adobe: 59.99, Canva: 12.99, Grammarly: 12,
  Todoist: 4, Trello: 5, Asana: 10.99, Linear: 8, Miro: 8, Loom: 12.5,
  Evernote: 10.83, Obsidian: 4, Airtable: 20, Slack: 8.75, Zoom: 15.99,
  Discord: 9.99, ChatGPT: 20, Claude: 20, Perplexity: 20, "GitHub Copilot": 10,
  Xbox: 16.99, PlayStation: 17.99, Steam: 0, "Epic Games": 0,
  "Nintendo Switch": 3.99, EA: 14.99, Ubisoft: 17.99, Roblox: 4.99,
  "New York Times": 17, Medium: 5, Substack: 5, Patreon: 5,
  Peloton: 12.99, Strava: 11.99, Fitbit: 9.99, Headspace: 12.99,
  Coursera: 49, Udemy: 16.58, Skillshare: 13.99, Duolingo: 6.99, LinkedIn: 39.99,
  GitHub: 4, Vercel: 20, Netlify: 19, Cloudflare: 5, DigitalOcean: 6,
  JetBrains: 16.9, Replit: 20, Framer: 5, Webflow: 14, WordPress: 4,
  Squarespace: 16, Shopify: 39, Mailchimp: 13, Zapier: 19.99,
  "1Password": 2.99, Bitwarden: 1, NordVPN: 12.99, ExpressVPN: 12.95,
  "Proton VPN": 9.99, Dashlane: 4.99,
  PayPal: 0, Stripe: 0, Revolut: 9.99, Wise: 0, Coinbase: 0, Robinhood: 5,
  Uber: 9.99, "Uber Eats": 9.99, Lyft: 9.99, DoorDash: 9.99, Airbnb: 0,
};

/** The expense picker: every bundled brand becomes a catalog entry with its
 *  real logo. Sorted so the most recognisable services surface first. */
export const CATALOG: CatalogItem[] = BRANDS.map((b) => ({
  name: b.name,
  color: b.hex,
  mark: b.name.trim().charAt(0).toUpperCase(),
  brandSlug: b.slug,
  category: b.category as CatalogItem["category"],
  amount: TYPICAL_PRICE[b.name] ?? 9.99,
}));

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
