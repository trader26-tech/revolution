import { useEffect, useState } from "react";
import { AnimatePresence, motion } from "framer-motion";
import { StoreProvider, useStore } from "@/data/store";
import { TabBar } from "@/components/ui/TabBar";
import type { Tab } from "@/components/ui/TabBar";
import { Sheet } from "@/components/ui/Sheet";
import { SpaceBackground } from "@/components/ui/SpaceBackground";
import { ConnectionBanner } from "@/components/ui/ConnectionBanner";
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

  const openDetail = (id: string) => {
    setActiveId(id);
    setSheet("detail");
  };
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
      <SpaceBackground />

      <ConnectionBanner />

      <main className="app__main no-scrollbar">
        <AnimatePresence mode="wait">
          <motion.div
            key={tab}
            initial={{ opacity: 0, y: 10 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: -8 }}
            transition={{ duration: 0.22, ease: [0.22, 1, 0.36, 1] }}
          >
            {tab === "home" && <SubscriptionsScreen onOpen={openDetail} />}
            {tab === "calendar" && <CalendarScreen onOpen={openDetail} />}
            {tab === "settings" && (
              <SettingsScreen onInstall={install} canInstall={!!installEvt} />
            )}
          </motion.div>
        </AnimatePresence>
      </main>

      <TabBar
        active={tab}
        onChange={(t) => {
          setTab(t);
          setSheet(null);
        }}
        onAdd={() => setSheet("add")}
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

  // TEMP-SEED: dev-only visual check. Remove before commit.
  useEffect(() => {
    if (!new URLSearchParams(location.search).has("seed")) return;
    const seed = [
      { name: "Netflix", color: "#e50914", mark: "N", category: "Streaming", amount: 649, currency: "INR", cycle: "monthly", list: "Personal", paymentMethod: "Visa", anchorDate: "2026-08-12" },
      { name: "Spotify", color: "#1db954", mark: "S", category: "Music", amount: 119, currency: "INR", cycle: "monthly", list: "Personal", paymentMethod: "Visa", anchorDate: "2026-08-03" },
      { name: "Amazon Prime", color: "#00a8e1", mark: "a", category: "Streaming", amount: 1499, currency: "INR", cycle: "yearly", list: "Personal", paymentMethod: "Amex", anchorDate: "2026-09-03" },
      { name: "ChatGPT Plus", color: "#10a37f", mark: "◉", category: "AI", amount: 1650, currency: "INR", cycle: "monthly", list: "Business", paymentMethod: "Visa", anchorDate: "2026-08-20" },
    ] as unknown as Parameters<typeof store.add>[0][];
    store.setCurrency("INR");
    localStorage.setItem(ONBOARDED_KEY, "1");
    setOnboarded(true);
    const t = setTimeout(() => seed.forEach((s) => store.add(s)), 300);
    return () => clearTimeout(t);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

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
      <Root />
    </StoreProvider>
  );
}
