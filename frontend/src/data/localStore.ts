import type { Subscription } from "@/lib/types";
import { seed } from "./seed";

const SUBS_KEY = "orbit.subs.v1";
const CUR_KEY = "orbit.currency.v1";

/** localStorage-backed cache. Doubles as the offline source of truth when
 *  the backend is unreachable or sync is disabled. */
export const localStore = {
  loadSubs(): Subscription[] {
    try {
      const raw = localStorage.getItem(SUBS_KEY);
      if (raw) return JSON.parse(raw) as Subscription[];
    } catch {
      /* corrupt cache — fall through to seed */
    }
    return seed();
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
