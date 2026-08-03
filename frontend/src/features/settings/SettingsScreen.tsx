import { useStore } from "@/data/store";
import { Planet } from "@/components/ui/Planet";
import { CURRENCIES } from "@/lib/catalog";
import "./settings.css";

const SYNC_LABEL: Record<string, string> = {
  disconnected: "Not connected to server",
  syncing: "Connecting…",
  synced: "Synced to cloud",
  error: "Server unreachable",
};

export function SettingsScreen({ onInstall, canInstall }: { onInstall: () => void; canInstall: boolean }) {
  const { currency, setCurrency, reset, subs, syncStatus } = useStore();

  return (
    <div className="set">
      <header className="set__head">
        <Planet size={40} glow />
        <div>
          <h2>Revolution</h2>
          <div className="set__ver">{subs.length} subscriptions · v1.0</div>
        </div>
      </header>

      {canInstall && (
        <button className="set__install" onClick={onInstall}>
          <span>📲 Add Revolution to your Home Screen</span>
          <small>Installs as an app — full screen, works offline</small>
        </button>
      )}

      <Group title="Preferences">
        <div className="set__row">
          <span>Data</span>
          <span className={"set__sync set__sync--" + syncStatus}>
            {SYNC_LABEL[syncStatus] ?? syncStatus}
          </span>
        </div>
        <div className="set__row">
          <span>Display currency</span>
          <select
            className="set__select"
            value={currency}
            onChange={(e) => setCurrency(e.target.value)}
          >
            {Object.keys(CURRENCIES).map((c) => (
              <option key={c}>{c}</option>
            ))}
          </select>
        </div>
        <div className="set__row">
          <span>Notifications</span>
          <span className="set__badge">On</span>
        </div>
        <div className="set__row">
          <span>Reminders before renewal</span>
          <span className="set__value">2 days</span>
        </div>
      </Group>

      <Group title="Finance that speaks your language">
        <div className="set__row"><span>Languages</span><span className="set__value">38</span></div>
        <div className="set__row"><span>Currencies</span><span className="set__value">64</span></div>
      </Group>

      <Group title="We're just getting started">
        {["Family sharing", "Mac app", "Better spending insights", "Flexible billing dates"].map(
          (f) => (
            <div key={f} className="set__row">
              <span>{f}</span>
              <span className="set__soon">Soon</span>
            </div>
          )
        )}
      </Group>

      <button
        className="set__reset"
        onClick={() => {
          if (confirm("Delete all subscriptions? This cannot be undone.")) reset();
        }}
      >
        Clear all data
      </button>

      <p className="set__made">Made with 💜 · Revolution</p>
    </div>
  );
}

function Group({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <section className="set__group">
      <div className="set__group-title">{title}</div>
      <div className="set__group-body">{children}</div>
    </section>
  );
}
