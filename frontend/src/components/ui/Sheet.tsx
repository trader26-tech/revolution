import type { ReactNode } from "react";
import { useEffect } from "react";
import "./sheet.css";

/** Bottom sheet. Enter animation is pure CSS (compositor transform); closing
 *  unmounts immediately — no animation library, no per-frame JS. */
export function Sheet({
  open,
  onClose,
  children,
  title,
}: {
  open: boolean;
  onClose: () => void;
  children: ReactNode;
  title?: string;
}) {
  useEffect(() => {
    if (open) {
      document.body.style.overflow = "hidden";
      return () => {
        document.body.style.overflow = "";
      };
    }
  }, [open]);

  if (!open) return null;

  return (
    <div className="sheet__scrim" onClick={onClose}>
      <div className="sheet" onClick={(e) => e.stopPropagation()}>
        <div className="sheet__grab" />
        {title && (
          <div className="sheet__head">
            <h2>{title}</h2>
            <button className="sheet__x" onClick={onClose} aria-label="Close">
              <svg viewBox="0 0 24 24" fill="none">
                <path d="M6 6l12 12M18 6L6 18" stroke="currentColor" strokeWidth="2" strokeLinecap="round" />
              </svg>
            </button>
          </div>
        )}
        <div className="sheet__body no-scrollbar">{children}</div>
      </div>
    </div>
  );
}
