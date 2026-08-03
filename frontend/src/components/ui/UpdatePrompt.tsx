import { useRegisterSW } from "virtual:pwa-register/react";
import "./update-prompt.css";

/**
 * PWA update prompt. When a new version of the app has been deployed, the
 * service worker installs it in the background and this dialog invites the user
 * to load it. Enter animation is pure CSS — no animation library.
 */
export function UpdatePrompt() {
  const {
    needRefresh: [needRefresh, setNeedRefresh],
    updateServiceWorker,
  } = useRegisterSW({
    immediate: true,
    onRegisteredSW(_swUrl, registration) {
      // poll for a new deploy every 60s while the app is open
      if (registration) {
        setInterval(() => registration.update(), 60_000);
      }
    },
  });

  const close = () => setNeedRefresh(false);

  if (!needRefresh) return null;

  return (
    <div className="upd__scrim" onClick={close}>
      <div
        className="upd glass glass--strong"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="upd__badge" aria-hidden>
          <svg viewBox="0 0 24 24" fill="none">
            <path d="M4 9a8 8 0 0 1 14-3l2 2M20 15a8 8 0 0 1-14 3l-2-2" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
            <path d="M20 4v4h-4M4 20v-4h4" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
          </svg>
        </div>
        <h2 className="upd__title">Update available</h2>
        <p className="upd__sub">
          A new version of Revolution is ready. Reload to get the latest.
        </p>
        <div className="upd__actions">
          <button className="upd__btn upd__btn--ghost" onClick={close}>
            Later
          </button>
          <button
            className="upd__btn upd__btn--primary"
            onClick={() => updateServiceWorker(true)}
          >
            Update now
          </button>
        </div>
      </div>
    </div>
  );
}
