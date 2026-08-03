import { memo, useCallback, useEffect, useState } from "react";
import type { ReactNode } from "react";
import { StoreProvider, useStore } from "@/data/store";
import { TabBar } from "@/components/ui/TabBar";
import type { Tab } from "@/components/ui/TabBar";
import { Sheet } from "@/components/ui/Sheet";
import { SpaceBackground } from "@/components/ui/SpaceBackground";
import { ConnectionBanner } from "@/components/ui/ConnectionBanner";
import { UpdatePrompt } from "@/components/ui/UpdatePrompt";
import {
  SubscriptionsScreen,
  SubscriptionDetail,
  SubscriptionForm,
} from "@/features/subscriptions";
import { CalendarScreen } from "@/features/calendar";
import { SettingsScreen } from "@/features/settings";
import { MagicImportScreen } from "@/features/import";
import { Onboarding } from "@/features/onboarding";
import type { NewSub } from "@/features/onboarding";
import "./App.css";

const ONBOARDED_KEY = "revolution.onboarded.v1";

type SheetKind = null | "add" | "magic" | "detail" | "edit";

interface BeforeInstallPromptEvent extends Event {
  prompt: () => Promise<void>;
  userChoice: Promise<{ outcome: string }>;
}

function Shell() {
  const store = useStore();
  const [tab, setTab] = useState<Tab>("home");
  const [sheet, setSheet] = useState<SheetKind>(null);
  const [activeId, setActiveId] = useState<string | null>(null);
  const [installEvt, setInstallEvt] = useState<BeforeInstallPromptEvent | null>(null);

  useEffect(() => {
    const h = (e: Event) => {
      e.preventDefault();
      setInstallEvt(e as BeforeInstallPromptEvent);
    };
    window.addEventListener("beforeinstallprompt", h);
    return () => window.removeEventListener("beforeinstallprompt", h);
  }, []);

  const install = async () => {
    if (!installEvt) return;
    await installEvt.prompt();
    await installEvt.userChoice;
    setInstallEvt(null);
  };

  /* PERF: stable identity. This is passed to the memoised <SunOrbit/>; if it
     were re-created each render the memo would never hit and all ~30 orbiting
     moons would re-render on every parent update. */
  const openDetail = useCallback((id: string) => {
    setActiveId(id);
    setSheet("detail");
  }, []);

  /* Stable too — an inline arrow here would break SubscriptionsScreen's memo
     and re-render the whole orbit on every parent update. */
  const openAdd = useCallback(() => setSheet("add"), []);
  const active = activeId ? store.get(activeId) : undefined;

  const sheetTitle =
    sheet === "add"
      ? "Add subscription"
      : sheet === "magic"
      ? "Magic Import"
      : sheet === "edit"
      ? "Edit subscription"
      : active?.name;

  return (
    <div className="app">
      <ConnectionBanner />

      {/* PERF — two deliberate choices here:
          1. No <AnimatePresence mode="wait">. That mode serialises the swap: it
             plays the outgoing screen's exit to completion BEFORE mounting the
             incoming one, so every tap cost the exit duration before anything
             appeared. That reads as lag, not polish.
          2. Screens stay MOUNTED and are toggled with `hidden`. Unmounting the
             home screen tore down the 30-moon orbit and re-ran every entry
             animation on the way back — the one switch that measurably stalled.
             Keeping them mounted makes every tab return a single cheap frame,
             and preserves each screen's scroll position for free. */}
      <main className="app__main no-scrollbar">
        <Screen active={tab === "home"}>
          <SubscriptionsScreen onOpen={openDetail} onAdd={openAdd} />
        </Screen>
        <Screen active={tab === "calendar"}>
          <CalendarScreen onOpen={openDetail} />
        </Screen>
        <Screen active={tab === "settings"}>
          <SettingsScreen onInstall={install} canInstall={!!installEvt} />
        </Screen>
      </main>

      <TabBar
        active={tab}
        onChange={(t) => {
          setTab(t);
          setSheet(null);
        }}
      />

      <Sheet open={sheet !== null} onClose={() => setSheet(null)} title={sheetTitle}>
        {sheet === "add" && (
          <div className="app__add-tabs">
            <div className="app__add-switch">
              <button className="is-on">Add manually</button>
              <button onClick={() => setSheet("magic")}>✨ Magic Import</button>
            </div>
            <SubscriptionForm onDone={() => setSheet(null)} />
          </div>
        )}
        {sheet === "magic" && <MagicImportScreen onDone={() => setSheet(null)} />}
        {sheet === "detail" && active && (
          <SubscriptionDetail sub={active} onEdit={() => setSheet("edit")} />
        )}
        {sheet === "edit" && active && (
          <SubscriptionForm editing={active} onDone={() => setSheet(null)} />
        )}
      </Sheet>
    </div>
  );
}

/** Keeps a screen mounted but hidden when it isn't the active tab.
 *
 *  `hidden` (the HTML attribute, via CSS `display:none`) removes the subtree
 *  from layout, paint AND animation entirely — an offscreen orbit costs
 *  nothing — while preserving component state and scroll position, so
 *  switching back is a single cheap frame instead of a full remount.
 *  It also correctly hides the subtree from assistive tech. */
const Screen = memo(function Screen({
  active,
  children,
}: {
  active: boolean;
  children: ReactNode;
}) {
  return (
    <div className="app__screen" hidden={!active}>
      {children}
    </div>
  );
});

/** Gates the app behind first-run onboarding. Lives inside the store so
 *  picks can be written straight through to the backend. */
function Root() {
  const store = useStore();
  const [onboarded, setOnboarded] = useState<boolean>(() => {
    try {
      return localStorage.getItem(ONBOARDED_KEY) === "1";
    } catch {
      return false;
    }
  });

  const finishOnboarding = (picks: NewSub[]) => {
    // Match the reference: onboarding runs in INR.
    store.setCurrency("INR");
    // Persist chosen subscriptions to the backend (source of truth).
    picks.forEach((p) => store.add(p));
    try {
      localStorage.setItem(ONBOARDED_KEY, "1");
    } catch {
      /* private mode — onboarding just shows again next launch */
    }
    setOnboarded(true);
  };

  if (!onboarded) {
    return <Onboarding currency="INR" onFinish={finishOnboarding} />;
  }
  return <Shell />;
}

export default function App() {
  return (
    <StoreProvider>
      {/* THE one and only background — a fixed starfield behind every screen,
          onboarding included. No other layer paints a page background. */}
      <SpaceBackground />
      <Root />
      {/* surfaces the "Update available" dialog when a new version deploys */}
      <UpdatePrompt />
    </StoreProvider>
  );
}
