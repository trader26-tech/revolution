# Bobo mascot art

Drop Bobo's animated art here. Each **mood** maps to one file. The app looks for
each mood in this priority order and uses the first that exists, so you can mix
formats:

1. `bobo_<mood>.webp`  ← **preferred** (animated WebP: full colour, transparency, small)
2. `bobo_<mood>.gif`   ← fine (animated GIF works too)
3. `bobo_<mood>.png`   ← static fallback

If none of the three exist for a mood, the app draws Bobo in code automatically,
so nothing ever breaks while art is missing.

## The moods and when each one shows

| File base            | Mood            | Shown when…                                         |
|----------------------|-----------------|-----------------------------------------------------|
| `bobo_happy`         | happy           | Fresh start / nothing to track yet                  |
| `bobo_sleepy`        | relaxed         | Everything calm — nothing due soon, nothing overdue |
| `bobo_scared`        | scared/sweating | A deadline is **very close** (a reminder due soon)  |
| `bobo_sad`           | sad             | Something was **forgotten** (a reminder is overdue) |
| `bobo_writing`       | noting it down  | While the user is picking/adding a reminder         |
| `bobo_celebrating`   | celebration     | Right after a reminder is **successfully added**    |
| `bobo_excited`       | excited         | (legacy/optional) waving, bouncy                    |

A full set is, e.g.:

```
bobo_happy.webp
bobo_sleepy.webp
bobo_scared.webp
bobo_sad.webp
bobo_writing.webp
bobo_celebrating.webp
```

## Format tips

- **Best: animated WebP.** Export your GIF to animated `.webp` — same single
  file, but full colour + real transparency + ~3× smaller. Flutter plays it
  natively via `Image.asset`.
- **GIF is fine** if that's what you have — just name it `bobo_<mood>.gif`.
- Use a **transparent background** so Bobo sits cleanly on the cream backdrop.
- Aim for a **square-ish canvas** (e.g. 512×512 or 600×640) — the widget fits it
  with `BoxFit.contain`, so square art centres nicely.
- Keep each file reasonably small (ideally < 500 KB) for smooth playback.

No pubspec change needed — `assets/images/` is already bundled. Restart the app
(not just hot-reload) after adding new asset files so Flutter picks them up.
