import type { Subscription } from "@/lib/types";
import { api } from "./client";

/** Backend record shape (snake_case, no client-only fields). */
interface ApiSubscription {
  id: string;
  name: string;
  color: string;
  mark: string;
  amount: number;
  currency: string;
  cycle: Subscription["cycle"];
  category: Subscription["category"];
  list: Subscription["list"];
  payment_method: string;
  anchor_date: string;
  is_trial: boolean;
  trial_ends: string | null;
  notes: string | null;
}

function fromApi(r: ApiSubscription): Subscription {
  return {
    id: r.id,
    name: r.name,
    color: r.color,
    mark: r.mark,
    amount: r.amount,
    currency: r.currency,
    cycle: r.cycle,
    category: r.category,
    list: r.list,
    paymentMethod: r.payment_method,
    anchorDate: r.anchor_date,
    isTrial: r.is_trial,
    trialEnds: r.trial_ends ?? undefined,
    notes: r.notes ?? undefined,
    // createdAt is a client-only ordering hint; synthesize if absent.
    createdAt: Date.now(),
  };
}

/** Only the fields the backend accepts (drops createdAt). */
function toApi(s: Partial<Subscription>): Partial<ApiSubscription> {
  const out: Partial<ApiSubscription> = {};
  if (s.id !== undefined) out.id = s.id;
  if (s.name !== undefined) out.name = s.name;
  if (s.color !== undefined) out.color = s.color;
  if (s.mark !== undefined) out.mark = s.mark;
  if (s.amount !== undefined) out.amount = s.amount;
  if (s.currency !== undefined) out.currency = s.currency;
  if (s.cycle !== undefined) out.cycle = s.cycle;
  if (s.category !== undefined) out.category = s.category;
  if (s.list !== undefined) out.list = s.list;
  if (s.paymentMethod !== undefined) out.payment_method = s.paymentMethod;
  if (s.anchorDate !== undefined) out.anchor_date = s.anchorDate;
  if (s.isTrial !== undefined) out.is_trial = s.isTrial;
  if (s.trialEnds !== undefined) out.trial_ends = s.trialEnds ?? null;
  if (s.notes !== undefined) out.notes = s.notes ?? null;
  return out;
}

export const subscriptionsApi = {
  async list(): Promise<Subscription[]> {
    const rows = await api<ApiSubscription[]>("/api/subscriptions");
    return rows.map(fromApi);
  },

  async create(sub: Subscription): Promise<Subscription> {
    const row = await api<ApiSubscription>("/api/subscriptions", {
      method: "POST",
      json: toApi(sub),
    });
    return fromApi(row);
  },

  async update(id: string, patch: Partial<Subscription>): Promise<Subscription> {
    const row = await api<ApiSubscription>(`/api/subscriptions/${id}`, {
      method: "PATCH",
      json: toApi(patch),
    });
    return fromApi(row);
  },

  async remove(id: string): Promise<void> {
    await api<void>(`/api/subscriptions/${id}`, { method: "DELETE" });
  },
};
