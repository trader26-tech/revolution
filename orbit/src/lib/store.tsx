import { createContext, useContext, useEffect, useMemo, useState } from "react";
import type { ReactNode } from "react";
import type { Subscription } from "./types";
import { seed } from "./seed";

const KEY = "orbit.subs.v1";
const CUR_KEY = "orbit.currency.v1";

interface Store {
  subs: Subscription[];
  currency: string;
  setCurrency: (c: string) => void;
  add: (s: Omit<Subscription, "id" | "createdAt">) => Subscription;
  update: (id: string, patch: Partial<Subscription>) => void;
  remove: (id: string) => void;
  get: (id: string) => Subscription | undefined;
  reset: () => void;
}

const Ctx = createContext<Store | null>(null);

function load(): Subscription[] {
  try {
    const raw = localStorage.getItem(KEY);
    if (raw) return JSON.parse(raw);
  } catch {
    /* ignore */
  }
  return seed();
}

function uid() {
  return Math.random().toString(36).slice(2, 10) + Date.now().toString(36);
}

export function StoreProvider({ children }: { children: ReactNode }) {
  const [subs, setSubs] = useState<Subscription[]>(load);
  const [currency, setCurrencyState] = useState<string>(
    () => localStorage.getItem(CUR_KEY) || "USD"
  );

  useEffect(() => {
    localStorage.setItem(KEY, JSON.stringify(subs));
  }, [subs]);

  const setCurrency = (c: string) => {
    setCurrencyState(c);
    localStorage.setItem(CUR_KEY, c);
  };

  const add: Store["add"] = (s) => {
    const full: Subscription = { ...s, id: uid(), createdAt: Date.now() };
    setSubs((prev) => [full, ...prev]);
    return full;
  };

  const update: Store["update"] = (id, patch) =>
    setSubs((prev) => prev.map((x) => (x.id === id ? { ...x, ...patch } : x)));

  const remove: Store["remove"] = (id) =>
    setSubs((prev) => prev.filter((x) => x.id !== id));

  const get = (id: string) => subs.find((x) => x.id === id);

  const reset = () => setSubs(seed());

  const value = useMemo<Store>(
    () => ({ subs, currency, setCurrency, add, update, remove, get, reset }),
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [subs, currency]
  );

  return <Ctx.Provider value={value}>{children}</Ctx.Provider>;
}

export function useStore() {
  const s = useContext(Ctx);
  if (!s) throw new Error("useStore outside provider");
  return s;
}
