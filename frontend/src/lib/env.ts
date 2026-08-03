/** Runtime configuration read from Vite env vars.
 *
 * `VITE_API_BASE_URL` points at the Revolution FastAPI backend. When it is empty
 * (the default), the app runs fully local: all data lives in localStorage and
 * no network calls are made. Set it in `.env` / `.env.local` to enable sync.
 */
export const API_BASE_URL = (import.meta.env.VITE_API_BASE_URL ?? "").replace(
  /\/$/,
  ""
);

export const SYNC_ENABLED = API_BASE_URL.length > 0;
