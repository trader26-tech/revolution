/* Generates src/lib/brands.generated.ts — a curated, offline suite of real
 * brand logos pulled from `simple-icons` (path + hex + title + slug).
 *
 * Run:  node scripts/gen-brands.mjs
 * Re-run whenever the curated list below changes or simple-icons updates.
 *
 * Only the curated brands are bundled (paths are ~150 bytes each), keeping the
 * app lean while still shipping real logos fully offline. Names the user types
 * that aren't here fall back to a tinted initial at runtime.
 */
import { readFileSync, writeFileSync, mkdirSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, resolve } from "node:path";
import { SUPPLEMENT } from "./brand-supplement.mjs";

const __dirname = dirname(fileURLToPath(import.meta.url));
const root = resolve(__dirname, "..");

const supByName = new Map(SUPPLEMENT.map((s) => [s.name, s]));

// Full simple-icons dataset (title, slug, hex).
const raw = JSON.parse(
  readFileSync(
    resolve(root, "node_modules/simple-icons/data/simple-icons.json"),
    "utf8"
  )
);
const icons = Array.isArray(raw) ? raw : raw.icons;
const all = icons.map((i) => ({ title: i.title, slug: i.slug, hex: i.hex }));

const byTitle = new Map(all.map((i) => [norm(i.title), i]));
const bySlug = new Map(all.map((i) => [i.slug, i]));

function norm(s) {
  return s.toLowerCase().replace(/[^a-z0-9]/g, "");
}

/** Resolve a friendly name to a simple-icons record, trying a few strategies. */
function resolveIcon(name, slugHint) {
  if (slugHint && bySlug.has(slugHint)) return bySlug.get(slugHint);
  const n = norm(name);
  if (byTitle.has(n)) return byTitle.get(n);
  // startsWith / includes fallback
  let hit = all.find((i) => norm(i.title) === n);
  if (hit) return hit;
  hit = all.find((i) => norm(i.title).startsWith(n));
  if (hit) return hit;
  hit = all.find((i) => n.length >= 4 && norm(i.title).includes(n));
  return hit || null;
}

/** Read the single <path d="…"> out of an icon's raw SVG. */
function pathFor(slug) {
  const svg = readFileSync(
    resolve(root, `node_modules/simple-icons/icons/${slug}.svg`),
    "utf8"
  );
  const m = svg.match(/ d="([^"]+)"/);
  return m ? m[1] : "";
}

// Curated suite. [display name, category, optional slug override]
const CURATED = [
  // Streaming / video
  ["Netflix", "Streaming"], ["Disney+", "Streaming", "disneyplus"],
  ["Prime Video", "Streaming", "primevideo"], ["YouTube Premium", "Streaming", "youtube"],
  ["HBO Max", "Streaming", "hbo"],
  ["Max", "Streaming", "max"], ["Hulu", "Streaming", "hulu"],
  ["Paramount+", "Streaming", "paramountplus"], ["Apple TV+", "Streaming", "appletv"],
  ["Crunchyroll", "Streaming", "crunchyroll"], ["Twitch", "Streaming"],
  ["Vimeo", "Streaming"], ["Audible", "Streaming", "audible"],
  // Music
  ["Spotify", "Music"], ["Apple Music", "Music", "applemusic"],
  ["Tidal", "Music", "tidal"], ["Deezer", "Music"], ["SoundCloud", "Music"],
  ["Bandcamp", "Music"], ["Pandora", "Music"],
  // Cloud / storage
  ["iCloud", "Cloud", "icloud"], ["Google Drive", "Cloud", "googledrive"],
  ["Dropbox", "Cloud"], ["Google One", "Cloud", "google"],
  ["Proton Drive", "Cloud", "protondrive"], ["pCloud", "Cloud", "pcloud"],
  ["Mega", "Cloud", "mega"],
  // Productivity / design
  ["Notion", "Productivity"], ["Figma", "Productivity"],
  ["Adobe", "Productivity", "adobe"], ["Canva", "Productivity", "canva"],
  ["Grammarly", "Productivity", "grammarly"], ["Todoist", "Productivity"],
  ["Trello", "Productivity"], ["Asana", "Productivity"], ["Linear", "Productivity"],
  ["Miro", "Productivity"], ["Loom", "Productivity"], ["Evernote", "Productivity"],
  ["Obsidian", "Productivity"], ["Airtable", "Productivity"],
  ["Slack", "Productivity"],
  ["Zoom", "Productivity", "zoom"], ["Discord", "Productivity"],
  // AI
  ["ChatGPT", "AI", "openai"], ["Claude", "AI", "anthropic"],
  ["Perplexity", "AI", "perplexity"],
  ["GitHub Copilot", "AI", "githubcopilot"],
  // Gaming
  ["Xbox", "Gaming", "xbox"], ["PlayStation", "Gaming", "playstation"],
  ["Steam", "Gaming"], ["Epic Games", "Gaming", "epicgames"],
  ["Nintendo Switch", "Gaming", "nintendoswitch"], ["EA", "Gaming", "ea"],
  ["Ubisoft", "Gaming"], ["Roblox", "Gaming"],
  // News / reading
  ["New York Times", "News", "newyorktimes"], ["Medium", "News"],
  ["Substack", "News"], ["Patreon", "News"],
  // Fitness
  ["Peloton", "Fitness"], ["Strava", "Fitness"], ["Fitbit", "Fitness"],
  ["Headspace", "Fitness", "headspace"],
  // Learning
  ["Coursera", "Other"], ["Udemy", "Other"], ["Skillshare", "Other"],
  ["Duolingo", "Other"], ["LinkedIn", "Other", "linkedin"],
  // Dev / hosting
  ["GitHub", "Productivity"], ["Vercel", "Cloud"], ["Netlify", "Cloud"],
  ["Cloudflare", "Cloud"], ["DigitalOcean", "Cloud"], ["JetBrains", "Productivity"],
  ["Replit", "Productivity"], ["Framer", "Productivity"], ["Webflow", "Productivity"],
  ["WordPress", "Other"], ["Squarespace", "Other"], ["Shopify", "Other"],
  ["Mailchimp", "Other", "mailchimp"], ["Zapier", "Other"],
  // Security / VPN / password
  ["1Password", "Utilities", "1password"], ["Bitwarden", "Utilities"],
  ["NordVPN", "Utilities"], ["ExpressVPN", "Utilities"], ["Proton VPN", "Utilities", "protonvpn"],
  ["Dashlane", "Utilities"],
  // Finance / money (also handy for income)
  ["PayPal", "Utilities"], ["Stripe", "Utilities"], ["Revolut", "Utilities"],
  ["Wise", "Utilities"], ["Coinbase", "Utilities"], ["Robinhood", "Utilities"],
  // Transport / food
  ["Uber", "Utilities"], ["Uber Eats", "Utilities", "ubereats"],
  ["Lyft", "Utilities"], ["DoorDash", "Utilities"], ["Airbnb", "Utilities"],
];

const out = [];
const missing = [];
const usedSupplement = [];
for (const [name, category, slugHint] of CURATED) {
  const rec = resolveIcon(name, slugHint);
  if (rec) {
    const path = pathFor(rec.slug);
    if (path) {
      out.push({ name, category, slug: rec.slug, hex: "#" + rec.hex, path });
      continue;
    }
  }
  // fall back to a hand-authored supplement glyph if we have one
  const sup = supByName.get(name);
  if (sup) {
    out.push({ name, category: sup.category, slug: sup.slug, hex: sup.hex, path: sup.path });
    usedSupplement.push(name);
    continue;
  }
  missing.push(name);
}

// append any supplement brands not already covered by the curated list
for (const s of SUPPLEMENT) {
  if (!out.some((b) => b.name === s.name)) {
    out.push({ name: s.name, category: s.category, slug: s.slug, hex: s.hex, path: s.path });
    usedSupplement.push(s.name);
  }
}

// de-dupe by display name (first wins)
const seen = new Set();
const brands = out.filter((b) => (seen.has(b.name) ? false : seen.add(b.name)));

const header = `// AUTO-GENERATED by scripts/gen-brands.mjs — do not edit by hand.
// Real brand logos from simple-icons (offline). Regenerate with:
//   node scripts/gen-brands.mjs
export interface Brand {
  name: string;
  category: string;
  slug: string;
  hex: string;
  /** single SVG path in a 0 0 24 24 viewBox */
  path: string;
}

export const BRANDS: Brand[] = ${JSON.stringify(brands, null, 0)};
`;

mkdirSync(resolve(root, "src/lib"), { recursive: true });
writeFileSync(resolve(root, "src/lib/brands.generated.ts"), header);

console.log(`wrote ${brands.length} brands to src/lib/brands.generated.ts`);
if (usedSupplement.length)
  console.log("supplement glyphs used:", [...new Set(usedSupplement)].join(", "));
if (missing.length) console.log("STILL unresolved:", missing.join(", "));
