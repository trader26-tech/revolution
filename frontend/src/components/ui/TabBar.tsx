import type { ReactNode } from "react";
import "./tabbar.css";

export type Tab = "home" | "calendar" | "insights" | "settings";

const TABS: { key: Tab; label: string; icon: ReactNode }[] = [
  {
    key: "home",
    label: "Subs",
    icon: (
      <svg viewBox="0 0 24 24" fill="none">
        <circle cx="12" cy="12" r="3.2" fill="currentColor" />
        <ellipse cx="12" cy="12" rx="9" ry="4.4" stroke="currentColor" strokeWidth="1.6" />
      </svg>
    ),
  },
  {
    key: "calendar",
    label: "Calendar",
    icon: (
      <svg viewBox="0 0 24 24" fill="none">
        <rect x="3.5" y="5" width="17" height="15" rx="3.5" stroke="currentColor" strokeWidth="1.6" />
        <path d="M3.5 9.5H20.5" stroke="currentColor" strokeWidth="1.6" />
        <path d="M8 3.5V6.5M16 3.5V6.5" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" />
      </svg>
    ),
  },
  {
    key: "insights",
    label: "Insights",
    icon: (
      <svg viewBox="0 0 24 24" fill="none">
        <path d="M5 19V10M12 19V5M19 19V13" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" />
      </svg>
    ),
  },
  {
    key: "settings",
    label: "Settings",
    icon: (
      <svg viewBox="0 0 24 24" fill="none">
        <circle cx="12" cy="12" r="3" stroke="currentColor" strokeWidth="1.6" />
        <path
          d="M12 2.8v2.2M12 19v2.2M4.4 7l1.9 1.1M17.7 15.9l1.9 1.1M4.4 17l1.9-1.1M17.7 8.1l1.9-1.1"
          stroke="currentColor"
          strokeWidth="1.6"
          strokeLinecap="round"
        />
      </svg>
    ),
  },
];

export function TabBar({
  active,
  onChange,
  onAdd,
}: {
  active: Tab;
  onChange: (t: Tab) => void;
  onAdd: () => void;
}) {
  return (
    <nav className="tabbar">
      <div className="tabbar__inner">
        {TABS.slice(0, 2).map((t) => (
          <TabButton key={t.key} tab={t} active={active === t.key} onClick={() => onChange(t.key)} />
        ))}

        <button className="tabbar__add" onClick={onAdd} aria-label="Add subscription">
          <svg viewBox="0 0 24 24" fill="none">
            <path d="M12 6v12M6 12h12" stroke="currentColor" strokeWidth="2.4" strokeLinecap="round" />
          </svg>
        </button>

        {TABS.slice(2).map((t) => (
          <TabButton key={t.key} tab={t} active={active === t.key} onClick={() => onChange(t.key)} />
        ))}
      </div>
    </nav>
  );
}

function TabButton({
  tab,
  active,
  onClick,
}: {
  tab: { key: Tab; label: string; icon: ReactNode };
  active: boolean;
  onClick: () => void;
}) {
  return (
    <button className={"tabbar__btn" + (active ? " is-active" : "")} onClick={onClick}>
      <span className="tabbar__icon">{tab.icon}</span>
      <span className="tabbar__label">{tab.label}</span>
    </button>
  );
}
