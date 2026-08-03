import {
  createContext,
  useContext,
  useEffect,
  useMemo,
  useRef,
  useState,
} from "react";
import type { ReactNode } from "react";
import type { Subscription } from "@/lib/types";
import { SYNC_ENABLED } from "@/lib/env";
import { localStore, newId } from "./localStore";
import { subscriptionsApi } from "./api/subscriptionsApi";

// "disconnected" — no backend configured (build-time VITE_API_BASE_URL missing).
// "error"        — backend configured but unreachable / request failed.
export type SyncStatus =
  | "disconnected"
  | "syncing"
  | "synced"
  | "error";

interface Store {
  subs: Subscription[];
  currency: string;
  syncStatus: SyncStatus;
  setCurrency: (c: string) => void;
  add: (s: Omit<Subscription, "id" | "createdAt">) => Subscription;
  update: (id: string, patch: Partial<Subscription>) => void;
  remove: (id: string) => void;
  get: (id: string) => Subscription | undefined;
  reset: () => void;
}

const Ctx = createContext<Store | null>(null);

export function StoreProvider({ children }: { children: ReactNode }) {
  // The backend is the ONLY source of truth. We start empty and never show
  // stale/local data — the list is populated solely from what the server
  // returns. If the server can't be reached, the list stays empty and the
  // ConnectionBanner explains why.
  const [subs, setSubs] = useState<Subscription[]>([]);
  const [currency, setCurrencyState] = useState<string>(localStore.loadCurrency);
  const [syncStatus, setSyncStatus] = useState<SyncStatus>(
    SYNC_ENABLED ? "syncing" : "disconnected"
  );

  // Refs let async callbacks read the latest state without re-subscribing.
  const subsRef = useRef(subs);
  subsRef.current = subs;

  // ---- load from the backend (the single source of truth) --------------
  useEffect(() => {
    if (!SYNC_ENABLED) {
      // No backend configured: never show anything stale.
      setSubs([]);
      return;
    }
    let cancelled = false;

    (async () => {
      try {
        const remote = await subscriptionsApi.list();
        if (cancelled) return;
        setSubs(remote);
        setSyncStatus("synced");
      } catch {
        // Unreachable: clear the list so no stale data is ever shown.
        if (!cancelled) {
          setSubs([]);
          setSyncStatus("error");
        }
      }
    })();

    return () => {
      cancelled = true;
    };
  }, []);

  const setCurrency = (c: string) => {
    setCurrencyState(c);
    localStore.saveCurrency(c);
  };

  // Pull the authoritative list from the backend after a failed write, so the
  // UI never keeps an optimistic change that didn't actually persist.
  const resyncFromServer = async () => {
    try {
      setSubs(await subscriptionsApi.list());
      setSyncStatus("synced");
    } catch {
      setSubs([]);
      setSyncStatus("error");
    }
  };

  // ---- mutations: optimistic locally, write-through to the API ---------
  // Writes require a backend. On failure we re-sync from the server so no
  // unsaved (stale) item lingers in the UI.
  const add: Store["add"] = (input) => {
    const full: Subscription = { ...input, id: newId(), createdAt: Date.now() };
    setSubs((prev) => [full, ...prev]);
    if (SYNC_ENABLED) {
      subscriptionsApi.create(full).catch(resyncFromServer);
    }
    return full;
  };

  const update: Store["update"] = (id, patch) => {
    setSubs((prev) => prev.map((x) => (x.id === id ? { ...x, ...patch } : x)));
    if (SYNC_ENABLED) {
      subscriptionsApi.update(id, patch).catch(resyncFromServer);
    }
  };

  const remove: Store["remove"] = (id) => {
    setSubs((prev) => prev.filter((x) => x.id !== id));
    if (SYNC_ENABLED) {
      subscriptionsApi.remove(id).catch(resyncFromServer);
    }
  };

  const get = (id: string) => subsRef.current.find((x) => x.id === id);

  // Clear everything — both local cache and, if connected, the backend.
  const reset = () => {
    setSubs([]);
    if (SYNC_ENABLED) {
      (async () => {
        try {
          const remote = await subscriptionsApi.list();
          await Promise.all(remote.map((s) => subscriptionsApi.remove(s.id)));
        } catch {
          setSyncStatus("error");
        }
      })();
    }
  };

  const value = useMemo<Store>(
    () => ({
      subs,
      currency,
      syncStatus,
      setCurrency,
      add,
      update,
      remove,
      get,
      reset,
    }),
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [subs, currency, syncStatus]
  );

  return <Ctx.Provider value={value}>{children}</Ctx.Provider>;
}

export function useStore() {
  const s = useContext(Ctx);
  if (!s) throw new Error("useStore outside provider");
  return s;
}
