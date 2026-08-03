import { useMemo, useState } from "react";
import { useStore } from "@/data/store";
import { CATALOG, PAYMENT_METHODS } from "@/lib/catalog";
import type {
  Category,
  CatalogItem,
  Cycle,
  ListName,
  Subscription,
} from "@/lib/types";
import "./form.css";

const CYCLES: { key: Cycle; label: string }[] = [
  { key: "weekly", label: "Weekly" },
  { key: "monthly", label: "Monthly" },
  { key: "yearly", label: "Yearly" },
];
const LISTS: ListName[] = ["Personal", "Family", "Business"];
const CATS: Category[] = [
  "Streaming", "Music", "Productivity", "Cloud", "AI",
  "Gaming", "Fitness", "News", "Utilities", "Other",
];

const todayISO = () => new Date().toISOString().slice(0, 10);

export function SubscriptionForm({
  editing,
  onDone,
}: {
  editing?: Subscription;
  onDone: () => void;
}) {
  const { add, update, remove, currency } = useStore();
  const [step, setStep] = useState<"pick" | "form">(editing ? "form" : "pick");
  const [query, setQuery] = useState("");

  const [form, setForm] = useState<Omit<Subscription, "id" | "createdAt">>(
    editing ?? {
      name: "",
      color: "#8a1cff",
      mark: "○",
      amount: 9.99,
      currency,
      cycle: "monthly",
      category: "Other",
      list: "Personal",
      paymentMethod: PAYMENT_METHODS[0],
      anchorDate: todayISO(),
    }
  );

  const results = useMemo(() => {
    const q = query.trim().toLowerCase();
    const base = q ? CATALOG.filter((c) => c.name.toLowerCase().includes(q)) : CATALOG;
    return base.slice(0, 24);
  }, [query]);

  const pick = (c: CatalogItem) => {
    setForm((f) => ({
      ...f,
      name: c.name,
      color: c.color,
      mark: c.mark,
      amount: c.amount,
      category: c.category,
    }));
    setStep("form");
  };

  const custom = () => {
    setForm((f) => ({ ...f, name: query || "New subscription" }));
    setStep("form");
  };

  const save = () => {
    if (!form.name.trim()) return;
    if (editing) update(editing.id, form);
    else add(form);
    onDone();
  };

  if (step === "pick") {
    return (
      <div className="ae">
        <div className="ae__search">
          <svg viewBox="0 0 24 24" fill="none" className="ae__search-ic">
            <circle cx="11" cy="11" r="6.5" stroke="currentColor" strokeWidth="1.8" />
            <path d="M20 20l-3.5-3.5" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" />
          </svg>
          <input
            autoFocus
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder="Search Netflix, Spotify, Figma…"
          />
        </div>

        <div className="ae__grid">
          {results.map((c) => (
            <button key={c.name} className="ae__tile" onClick={() => pick(c)}>
              <span className="ae__tile-logo" style={{ background: c.color }}>
                {c.mark}
              </span>
              <span className="ae__tile-name">{c.name}</span>
            </button>
          ))}
        </div>

        <button className="ae__custom" onClick={custom}>
          + Add “{query || "custom"}” manually
        </button>
      </div>
    );
  }

  return (
    <div className="ae">
      <div className="ae__preview">
        <span className="ae__preview-logo" style={{ background: form.color }}>
          {form.mark}
        </span>
        <div>
          <div className="ae__preview-name">{form.name || "New subscription"}</div>
          <div className="ae__preview-sub">{form.category} · {form.list}</div>
        </div>
      </div>

      <Field label="Name">
        <input
          className="in"
          value={form.name}
          onChange={(e) => setForm({ ...form, name: e.target.value })}
          placeholder="Subscription name"
        />
      </Field>

      <div className="ae__row2">
        <Field label="Amount">
          <input
            className="in"
            type="number"
            inputMode="decimal"
            step="0.01"
            value={form.amount}
            onChange={(e) => setForm({ ...form, amount: parseFloat(e.target.value) || 0 })}
          />
        </Field>
        <Field label="Currency">
          <select
            className="in"
            value={form.currency}
            onChange={(e) => setForm({ ...form, currency: e.target.value })}
          >
            {["USD", "EUR", "GBP", "INR", "JPY", "AUD", "CAD"].map((c) => (
              <option key={c}>{c}</option>
            ))}
          </select>
        </Field>
      </div>

      <Field label="Billing cycle">
        <Segmented
          options={CYCLES.map((c) => ({ key: c.key, label: c.label }))}
          value={form.cycle}
          onChange={(v) => setForm({ ...form, cycle: v as Cycle })}
        />
      </Field>

      <Field label="Next payment">
        <input
          className="in"
          type="date"
          value={form.anchorDate}
          onChange={(e) => setForm({ ...form, anchorDate: e.target.value })}
        />
      </Field>

      <Field label="List">
        <Segmented
          options={LISTS.map((l) => ({ key: l, label: l }))}
          value={form.list}
          onChange={(v) => setForm({ ...form, list: v as ListName })}
        />
      </Field>

      <Field label="Category">
        <div className="ae__cats no-scrollbar">
          {CATS.map((c) => (
            <button
              key={c}
              className={"chip" + (form.category === c ? " is-on" : "")}
              onClick={() => setForm({ ...form, category: c })}
            >
              {c}
            </button>
          ))}
        </div>
      </Field>

      <Field label="Payment method">
        <select
          className="in"
          value={form.paymentMethod}
          onChange={(e) => setForm({ ...form, paymentMethod: e.target.value })}
        >
          {PAYMENT_METHODS.map((p) => (
            <option key={p}>{p}</option>
          ))}
        </select>
      </Field>

      <label className="ae__trial">
        <span>Free trial</span>
        <input
          type="checkbox"
          checked={!!form.isTrial}
          onChange={(e) =>
            setForm({
              ...form,
              isTrial: e.target.checked,
              trialEnds: e.target.checked ? form.anchorDate : undefined,
            })
          }
        />
      </label>

      <div className="ae__actions">
        {editing && (
          <button
            className="btn btn--ghost btn--danger"
            onClick={() => {
              remove(editing.id);
              onDone();
            }}
          >
            Delete
          </button>
        )}
        <button className="btn btn--primary" onClick={save}>
          {editing ? "Save changes" : "Add to orbit"}
        </button>
      </div>
    </div>
  );
}

function Field({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div className="field">
      <div className="field__label">{label}</div>
      {children}
    </div>
  );
}

function Segmented({
  options,
  value,
  onChange,
}: {
  options: { key: string; label: string }[];
  value: string;
  onChange: (v: string) => void;
}) {
  return (
    <div className="seg">
      {options.map((o) => (
        <button
          key={o.key}
          className={"seg__btn" + (value === o.key ? " is-on" : "")}
          onClick={() => onChange(o.key)}
        >
          {o.label}
        </button>
      ))}
    </div>
  );
}
