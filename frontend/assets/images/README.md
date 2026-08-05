# Bobo mascot — image drop-in slot

Drop **three PNGs** here to give Bobo his illustrated look. Exact filenames:

| File                 | Pose                                            | Shown when                        |
|----------------------|-------------------------------------------------|-----------------------------------|
| `bobo_happy.png`     | calm / sitting, content smile                   | nothing due — all caught up       |
| `bobo_excited.png`   | waving paw / bouncy, big smile                  | a reminder is due soon or overdue |
| `bobo_sleepy.png`    | eyes closed / resting                           | quiet hours / all clear           |

Guidelines for a great result:

- **Transparent background** (PNG with alpha) — no green/solid backdrop. If the
  files come with a solid background, they'll still display, but they look best
  transparent.
- **Square-ish, high-res** (e.g. 1024×1024), dog centred with a little padding.
- Keep the **same art style** across all three so Bobo reads as one character.

Behaviour:

- `BoboMascot` shows the PNG for the current mood and animates it (a gentle
  breathing bob, plus a little bounce when tapped).
- If a file is missing, Bobo automatically falls back to the built-in
  code-drawn version, so the app never breaks — add the files whenever you're
  ready.
