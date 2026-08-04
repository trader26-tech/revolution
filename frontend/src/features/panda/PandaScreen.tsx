import { useEffect, useState } from "react";
import { PandaMascot } from "./PandaMascot";
import "./panda.css";

/* The notes Pip "writes" — they type themselves into the feed, one after the
   other, so the page feels alive alongside the mascot. */
const NOTES = [
  "Netflix renews in 3 days — ₹649",
  "Cancel Peloton trial before Fri",
  "Spotify + YouTube = ₹298/mo",
  "Move iCloud to yearly, save 16%",
  "Salary lands on the 1st 🎉",
  "3 trials ending this week",
];

export function PandaScreen() {
  return (
    <div className="pd">
      <header className="pd__head">
        <h2 className="pd__title">Meet Pip</h2>
        <p className="pd__sub">Your notes-keeping panda, always on the job.</p>
      </header>

      {/* the mascot on its own little stage */}
      <div className="pd__stage">
        <div className="pd__glow" aria-hidden />
        <PandaMascot size={230} />
        <div className="pd__status">
          <span className="pd__status-dot" />
          jotting things down…
        </div>
      </div>

      {/* a live feed that types itself in, in sync with the theme */}
      <div className="pd__notes glass">
        <div className="pd__notes-head">
          <span className="pd__notes-title">Pip's notepad</span>
          <span className="pd__notes-count">live</span>
        </div>
        <NoteFeed />
      </div>
    </div>
  );
}

/** Types out notes one character at a time, then moves to the next, looping —
 *  a tiny "someone is writing this right now" effect. */
function NoteFeed() {
  const [done, setDone] = useState<string[]>([]);
  const [typed, setTyped] = useState("");
  const [i, setI] = useState(0);

  useEffect(() => {
    const full = NOTES[i % NOTES.length];

    if (typed.length < full.length) {
      const id = setTimeout(() => setTyped(full.slice(0, typed.length + 1)), 45);
      return () => clearTimeout(id);
    }

    // finished this line — pause, commit it, advance (keeping the last 4)
    const id = setTimeout(() => {
      setDone((d) => [full, ...d].slice(0, 4));
      setTyped("");
      setI((n) => n + 1);
    }, 1100);
    return () => clearTimeout(id);
  }, [typed, i]);

  return (
    <ul className="pd__feed">
      <li className="pd__note pd__note--active">
        <span className="pd__note-bullet" />
        <span className="pd__note-text">
          {typed}
          <span className="pd__caret" />
        </span>
      </li>
      {done.map((n, k) => (
        <li className="pd__note" key={n + k} style={{ opacity: 1 - k * 0.22 }}>
          <span className="pd__note-bullet pd__note-bullet--done" />
          <span className="pd__note-text">{n}</span>
        </li>
      ))}
    </ul>
  );
}
