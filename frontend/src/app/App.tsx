import { useEffect, useState } from "react";
import { AnimatePresence, motion } from "framer-motion";
import { StoreProvider, useStore } from "@/data/store";
import { TabBar } from "@/components/ui/TabBar";
import type { Tab } from "@/components/ui/TabBar";
import { Sheet } from "@/components/ui/Sheet";
import {
  SubscriptionsScreen,
  SubscriptionDetail,
  SubscriptionForm,
} from "@/features/subscriptions";
import { CalendarScreen } from "@/features/calendar";
import { InsightsScreen } from "@/features/insights";
import { SettingsScreen } from "@/features/settings";
import { MagicImportScreen } from "@/features/import";
import "./App.css";

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
      <div className="space-bg" />

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
            {tab === "insights" && <InsightsScreen />}
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

export default function App() {
  return (
    <StoreProvider>
      <Shell />
    </StoreProvider>
  );
}
