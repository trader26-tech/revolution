import { useStore } from "@/data/store";
import "./connection-banner.css";

/** A prominent banner shown when the app is NOT talking to the backend.
 *
 * - "disconnected": no backend configured (the build had no VITE_API_BASE_URL).
 * - "error":        backend configured but unreachable / a request failed.
 *
 * Hidden while syncing or once synced. The app never shows demo data, so this
 * is how the user learns their data isn't being saved to the server.
 */
export function ConnectionBanner() {
  const { syncStatus } = useStore();

  if (syncStatus !== "disconnected" && syncStatus !== "error") return null;

  const disconnected = syncStatus === "disconnected";

  return (
    <div
      className={"conn-banner conn-banner--" + syncStatus}
      role="alert"
      aria-live="polite"
    >
      <span className="conn-banner__dot" aria-hidden="true" />
      <span className="conn-banner__text">
        {disconnected ? (
          <>
            <strong>Not connected to the server.</strong> Changes won’t be
            saved. The app isn’t configured with a backend URL.
          </>
        ) : (
          <>
            <strong>Can’t reach the server.</strong> Changes won’t be saved
            until the connection is back.
          </>
        )}
      </span>
    </div>
  );
}
