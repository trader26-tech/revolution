import {
  createContext,
  useCallback,
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
export type SyncStatus = "disconnected" | "syncing" | "synced" | "error";

/** The data half: changes whenever the user's records change. */
interface StoreState {
  subs: Subscription[];
  currency: string;
  syncStatus: SyncStatus;
}

/** The actions half: every function is referentially STABLE for the lifetime of
 *  the provider, so components that only dispatch never re-render. */
interface StoreActions {
  setCurrency: (c: string) => void;
  add: (s: Omit<Subscription, "id" | "createdAt">) => Subscription;
  update: (id: string, patch: Partial<Subscription>) => void;
  remove: (id: string) => void;
  get: (id: string) => Subscription | undefined;
  reset: () => void;
}

/* ---------------------------------------------------------------------------
   PERFORMANCE — why two contexts instead of one.

   Previously a single context carried both the data and the action functions.
   The actions were re-created on every render, so the context value changed
   identity on EVERY state change, and every consumer of `useStore()` re-rendered
   — including screens that only ever call `add()`. With the orbit animating,
   those cascades landed on top of animation frames and produced visible jank.

   Splitting them means:
     • `useStoreActions()` never causes a re-render (value never changes).
     • `useStoreState()` re-renders only on genuine data change.
     • `useSubs()` / `useCurrency()` narrow further so a currency switch does not
       re-render subscription lists and vice-versa.
--------------------------------------------------------------------------- */
const StateCtx = createContext<StoreState | null>(null);
const ActionsCtx = createContext<StoreActions | null>(null);

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

  // Refs let the (stable) actions read the latest state without being
  // re-created when it changes — this is what keeps their identity fixed.
  const subsRef = useRef(subs);
  subsRef.current = subs;

  // ---- load from the backend (the single source of truth) --------------
  useEffect(() => {
    if (!SYNC_ENABLED) {
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

  // Pull the authoritative list from the backend after a failed write, so the
  // UI never keeps an optimistic change that didn't actually persist.
  const resyncFromServer = useCallback(async () => {
    try {
      setSubs(await subscriptionsApi.list());
      setSyncStatus("synced");
    } catch {
      setSubs([]);
      setSyncStatus("error");
    }
  }, []);

  const setCurrency = useCallback((c: string) => {
    setCurrencyState(c);
    localStore.saveCurrency(c);
  }, []);

  // ---- mutations: optimistic locally, write-through to the API ---------
  const add = useCallback<StoreActions["add"]>(
    (input) => {
      const full: Subscription = { ...input, id: newId(), createdAt: Date.now() };
      setSubs((prev) => [full, ...prev]);
      if (SYNC_ENABLED) {
        subscriptionsApi.create(full).catch(resyncFromServer);
      }
      return full;
    },
    [resyncFromServer]
  );

  const update = useCallback<StoreActions["update"]>(
    (id, patch) => {
      setSubs((prev) => prev.map((x) => (x.id === id ? { ...x, ...patch } : x)));
      if (SYNC_ENABLED) {
        subscriptionsApi.update(id, patch).catch(resyncFromServer);
      }
    },
    [resyncFromServer]
  );

  const remove = useCallback<StoreActions["remove"]>(
    (id) => {
      setSubs((prev) => prev.filter((x) => x.id !== id));
      if (SYNC_ENABLED) {
        subscriptionsApi.remove(id).catch(resyncFromServer);
      }
    },
    [resyncFromServer]
  );

  // reads through a ref, so it never needs to change identity
  const get = useCallback(
    (id: string) => subsRef.current.find((x) => x.id === id),
    []
  );

  const reset = useCallback(() => {
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
  }, []);

  // Actions are memoised on stable callbacks → this object is created ONCE.
  const actions = useMemo<StoreActions>(
    () => ({ setCurrency, add, update, remove, get, reset }),
    [setCurrency, add, update, remove, get, reset]
  );

  const state = useMemo<StoreState>(
    () => ({ subs, currency, syncStatus }),
    [subs, currency, syncStatus]
  );

  return (
    <ActionsCtx.Provider value={actions}>
      <StateCtx.Provider value={state}>{children}</StateCtx.Provider>
    </ActionsCtx.Provider>
  );
}

/** Actions only — subscribing to this NEVER triggers a re-render. */
export function useStoreActions() {
  const a = useContext(ActionsCtx);
  if (!a) throw new Error("useStoreActions outside provider");
  return a;
}

/** Data only — re-renders when records / currency / sync status change. */
export function useStoreState() {
  const s = useContext(StateCtx);
  if (!s) throw new Error("useStoreState outside provider");
  return s;
}

/** Narrow selectors, so a component only re-renders for what it actually uses. */
export function useSubs() {
  return useStoreState().subs;
}
export function useCurrency() {
  return useStoreState().currency;
}
export function useSyncStatus() {
  return useStoreState().syncStatus;
}

/** Back-compat facade for call sites that want everything at once.
 *  Prefer the narrow hooks above in new code — this one re-renders on any
 *  state change by definition. */
export function useStore() {
  const state = useStoreState();
  const actions = useStoreActions();
  return useMemo(() => ({ ...state, ...actions }), [state, actions]);
}
