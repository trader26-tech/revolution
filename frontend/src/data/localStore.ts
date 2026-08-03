const SUBS_KEY = "orbit.subs.v1";
const CUR_KEY = "revolution.currency.v1";

// The backend is the sole source of truth for subscriptions, so we never
// cache them locally (that would risk showing stale data). Proactively drop
// any subscription cache left over from older builds that used to seed demo
// data, so it can never resurface.
try {
  localStorage.removeItem(SUBS_KEY);
  // clean up the old currency key too if present
  const legacy = localStorage.getItem("orbit.currency.v1");
  if (legacy && !localStorage.getItem(CUR_KEY)) {
    localStorage.setItem(CUR_KEY, legacy);
    localStorage.removeItem("orbit.currency.v1");
  }
} catch {
  /* private mode / unavailable — non-fatal */
}

/** localStorage for the small bits of UI state that aren't server data.
 *  Subscriptions are intentionally NOT stored here. */
export const localStore = {
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
