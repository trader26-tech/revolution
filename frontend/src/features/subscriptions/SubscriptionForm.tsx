import { useMemo, useState } from "react";
import { useStore } from "@/data/store";
import { CATALOG, INCOME_CATALOG, PAYMENT_METHODS } from "@/lib/catalog";
import type {
  Category,
  CatalogItem,
  Cycle,
  Flow,
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
const EXPENSE_CATS: Category[] = [
  "Streaming", "Music", "Productivity", "Cloud", "AI",
  "Gaming", "Fitness", "News", "Utilities", "Other",
];
const INCOME_CATS: Category[] = [
  "Salary", "Freelance", "Dividends", "Rental", "Refunds", "Other",
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
  /** Which side of the ledger the picker is showing. */
  const [flow, setFlow] = useState<Flow>(editing?.flow ?? "expense");

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
      flow: "expense",
      paymentMethod: PAYMENT_METHODS[0],
      anchorDate: todayISO(),
    }
  );

  const results = useMemo(() => {
    const source = flow === "income" ? INCOME_CATALOG : CATALOG;
    const q = query.trim().toLowerCase();
    const base = q ? source.filter((c) => c.name.toLowerCase().includes(q)) : source;
    return base.slice(0, 24);
  }, [query, flow]);

  /** Switching sides in the picker also switches the record being built. */
  const switchFlow = (next: Flow) => {
    setFlow(next);
    setForm((f) => ({
      ...f,
      flow: next,
      category: next === "income" ? "Salary" : "Other",
    }));
  };

  const pick = (c: CatalogItem) => {
    setForm((f) => ({
      ...f,
      name: c.name,
      color: c.color,
      mark: c.mark,
      amount: c.amount,
      category: c.category,
      flow: c.flow ?? flow,
    }));
    setStep("form");
  };

  const custom = () => {
    setForm((f) => ({
      ...f,
      name: query || (flow === "income" ? "New income" : "New subscription"),
      flow,
    }));
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
        {/* which side of the ledger are we adding? */}
        <div className="ae__flow glass">
          <button
            className={"ae__flow-btn" + (flow === "expense" ? " is-on is-expense" : "")}
            onClick={() => switchFlow("expense")}
          >
            − Expense
          </button>
          <button
            className={"ae__flow-btn" + (flow === "income" ? " is-on is-income" : "")}
            onClick={() => switchFlow("income")}
          >
            + Income
          </button>
        </div>

        <div className="ae__search glass">
          <svg viewBox="0 0 24 24" fill="none" className="ae__search-ic">
            <circle cx="11" cy="11" r="6.5" stroke="currentColor" strokeWidth="1.8" />
            <path d="M20 20l-3.5-3.5" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" />
          </svg>
          <input
            autoFocus
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder={
              flow === "income"
                ? "Search Salary, Freelance…"
                : "Search Netflix, Spotify, Figma…"
            }
          />
        </div>

        <div className="ae__grid">
          {results.map((c) => (
            <button
              key={c.name}
              className="ae__tile glass glass--tap"
              onClick={() => pick(c)}
            >
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

  const isIncomeForm = form.flow === "income";

  return (
    <div className="ae">
      <div className={"ae__preview glass " + (isIncomeForm ? "is-income" : "is-expense")}>
        <span className="ae__preview-logo" style={{ background: form.color }}>
          {form.mark}
        </span>
        <div>
          <div className="ae__preview-name">
            {form.name || (isIncomeForm ? "New income" : "New subscription")}
          </div>
          <div className="ae__preview-sub">{form.category} · {form.list}</div>
        </div>
        <span className={"ae__preview-flow " + (isIncomeForm ? "is-income" : "is-expense")}>
          {isIncomeForm ? "Income" : "Expense"}
        </span>
      </div>

      <Field label="Type">
        <div className="ae__flow glass">
          <button
            className={"ae__flow-btn" + (!isIncomeForm ? " is-on is-expense" : "")}
            onClick={() => switchFlow("expense")}
          >
            − Expense
          </button>
          <button
            className={"ae__flow-btn" + (isIncomeForm ? " is-on is-income" : "")}
            onClick={() => switchFlow("income")}
          >
            + Income
          </button>
        </div>
      </Field>

      <Field label="Name">
        <input
          className="in"
          value={form.name}
          onChange={(e) => setForm({ ...form, name: e.target.value })}
          placeholder={isIncomeForm ? "Income source" : "Subscription name"}
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

      <Field label={isIncomeForm ? "Next payout" : "Next payment"}>
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
          {(isIncomeForm ? INCOME_CATS : EXPENSE_CATS).map((c) => (
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

      <Field label={isIncomeForm ? "Paid into" : "Payment method"}>
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

      {/* trials only apply to money going out */}
      {!isIncomeForm && (
        <label className="ae__trial glass">
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
      )}

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
        <button
          className={"btn " + (isIncomeForm ? "btn--income" : "btn--primary")}
          onClick={save}
        >
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
