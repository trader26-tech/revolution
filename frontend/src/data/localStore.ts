import type { Subscription } from "@/lib/types";

const SUBS_KEY = "orbit.subs.v1";
const CUR_KEY = "orbit.currency.v1";

/** localStorage-backed cache of what the backend last returned. Never seeds
 *  demo data — an empty/missing cache means "no data yet", not fake content. */
export const localStore = {
  loadSubs(): Subscription[] {
    try {
      const raw = localStorage.getItem(SUBS_KEY);
      if (raw) return JSON.parse(raw) as Subscription[];
    } catch {
      /* corrupt cache — treat as empty */
    }
    return [];
  },

  saveSubs(subs: Subscription[]): void {
    try {
      localStorage.setItem(SUBS_KEY, JSON.stringify(subs));
    } catch {
      /* quota / private mode — non-fatal */
    }
  },

  loadCurrency(): string {
    return localStorage.getItem(CUR_KEY) || "USD";
  },

  saveCurrency(c: string): void {
    localStorage.setItem(CUR_KEY, c);
  },
};

export function newId(): string {
  return Math.random().toString(36).slice(2, 10) + Date.now().toString(36);
}
