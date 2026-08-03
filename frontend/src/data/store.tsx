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
import { seed } from "./seed";
import { subscriptionsApi } from "./api/subscriptionsApi";

export type SyncStatus = "local" | "syncing" | "synced" | "error";

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
  const [subs, setSubs] = useState<Subscription[]>(localStore.loadSubs);
  const [currency, setCurrencyState] = useState<string>(localStore.loadCurrency);
  const [syncStatus, setSyncStatus] = useState<SyncStatus>(
    SYNC_ENABLED ? "syncing" : "local"
  );

  // always keep the local cache in step with state
  useEffect(() => localStore.saveSubs(subs), [subs]);

  // ---- initial hydration from the backend (if configured) --------------
  // Refs let async callbacks read the latest local state without re-subscribing.
  const subsRef = useRef(subs);
  subsRef.current = subs;

  useEffect(() => {
    if (!SYNC_ENABLED) return;
    let cancelled = false;

    (async () => {
      try {
        const remote = await subscriptionsApi.list();
        if (cancelled) return;
        if (remote.length > 0) {
          setSubs(remote);
        } else {
          // empty backend: push the current local set up so both agree
          await Promise.all(
            subsRef.current.map((s) => subscriptionsApi.create(s))
          );
        }
        setSyncStatus("synced");
      } catch {
        // offline / not reachable: keep working from the local cache
        if (!cancelled) setSyncStatus("error");
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

  // ---- mutations: optimistic locally, write-through to the API ---------
  const add: Store["add"] = (input) => {
    const full: Subscription = { ...input, id: newId(), createdAt: Date.now() };
    setSubs((prev) => [full, ...prev]);
    if (SYNC_ENABLED) {
      subscriptionsApi.create(full).catch(() => setSyncStatus("error"));
    }
    return full;
  };

  const update: Store["update"] = (id, patch) => {
    setSubs((prev) => prev.map((x) => (x.id === id ? { ...x, ...patch } : x)));
    if (SYNC_ENABLED) {
      subscriptionsApi.update(id, patch).catch(() => setSyncStatus("error"));
    }
  };

  const remove: Store["remove"] = (id) => {
    setSubs((prev) => prev.filter((x) => x.id !== id));
    if (SYNC_ENABLED) {
      subscriptionsApi.remove(id).catch(() => setSyncStatus("error"));
    }
  };

  const get = (id: string) => subsRef.current.find((x) => x.id === id);

  const reset = () => {
    const fresh = seed();
    setSubs(fresh);
    if (SYNC_ENABLED) {
      // replace the remote set with the fresh demo data
      (async () => {
        try {
          const remote = await subscriptionsApi.list();
          await Promise.all(remote.map((s) => subscriptionsApi.remove(s.id)));
          await Promise.all(fresh.map((s) => subscriptionsApi.create(s)));
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
