import { BRANDS } from "./brands.generated";
import type { Brand } from "./brands.generated";

export type { Brand };
export { BRANDS };

const norm = (s: string) => s.toLowerCase().replace(/[^a-z0-9]/g, "");

// name/alias → brand, built once.
const index = new Map<string, Brand>();
for (const b of BRANDS) {
  index.set(norm(b.name), b);
  index.set(norm(b.slug.replace(/^x-/, "")), b);
}

/** Resolve a free-text name to a bundled brand logo, or null if none fits.
 *
 *  Strategy, cheapest first:
 *   1. exact normalised name/slug hit
 *   2. brand name is a prefix of the query (or vice-versa) — "netflix uhd" → Netflix
 *   3. token overlap — any word of the query equals a brand's first word
 */
export function matchBrand(query: string): Brand | null {
  const q = norm(query);
  if (!q) return null;

  const exact = index.get(q);
  if (exact) return exact;

  // prefix either direction, longest brand name wins (most specific)
  let best: Brand | null = null;
  let bestLen = 0;
  for (const b of BRANDS) {
    const n = norm(b.name);
    if (q.startsWith(n) || n.startsWith(q)) {
      if (n.length > bestLen) {
        best = b;
        bestLen = n.length;
      }
    }
  }
  if (best) return best;

  // token match: first word of the query
  const firstWord = query.trim().split(/\s+/)[0];
  const fw = norm(firstWord);
  if (fw.length >= 3) {
    const hit = BRANDS.find((b) => {
      const bn = norm(b.name.split(/\s+/)[0]);
      return bn === fw || (fw.length >= 4 && bn.includes(fw));
    });
    if (hit) return hit;
  }

  return null;
}

/** Brands whose name/category match a search string, for the picker grid. */
export function searchBrands(query: string, limit = 60): Brand[] {
  const q = norm(query);
  if (!q) return BRANDS.slice(0, limit);
  const starts: Brand[] = [];
  const includes: Brand[] = [];
  for (const b of BRANDS) {
    const n = norm(b.name);
    if (n.startsWith(q)) starts.push(b);
    else if (n.includes(q) || norm(b.category).includes(q)) includes.push(b);
  }
  return [...starts, ...includes].slice(0, limit);
}
