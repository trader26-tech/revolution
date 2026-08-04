import type { ReactNode } from "react";
import "./tabbar.css";

export type Tab = "home" | "calendar" | "panda" | "settings";

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
    key: "panda",
    label: "Pip",
    icon: (
      // a little panda face
      <svg viewBox="0 0 24 24" fill="none">
        <circle cx="6.5" cy="5.5" r="2.4" fill="currentColor" />
        <circle cx="17.5" cy="5.5" r="2.4" fill="currentColor" />
        <circle cx="12" cy="12.5" r="8" stroke="currentColor" strokeWidth="1.6" />
        <ellipse cx="9" cy="11.5" rx="1.7" ry="2.1" fill="currentColor" />
        <ellipse cx="15" cy="11.5" rx="1.7" ry="2.1" fill="currentColor" />
        <circle cx="12" cy="15" r="1.1" fill="currentColor" />
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
}: {
  active: Tab;
  onChange: (t: Tab) => void;
}) {
  return (
    <nav className="tabbar">
      <div className="tabbar__inner">
        {TABS.map((t) => (
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
