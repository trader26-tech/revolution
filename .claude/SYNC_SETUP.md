# Multi-machine dev sync

Two Macs, GitHub in the middle. Nothing talks peer-to-peer.

- **M5 (this Mac)** — you + AI agents write code. Auto-commits & pushes to GitHub
  every time an agent finishes.
- **M4 mini** — runs the Android emulator + iOS simulator. Auto-pulls on every
  push and hot-reloads both.

Repo: `https://github.com/trader26-tech/revolution` · Flutter app in `frontend/`.

---

## M5 (code machine) — already set up

- **Auto-push on agent finish:** the Claude Code `Stop` hook runs
  `.claude/scripts/auto-commit.sh` → stages `backend/ frontend/ .claude/
  README.md .gitignore`, commits, and pushes the current branch. If the push is
  rejected (origin moved ahead), it rebases and retries once.
- **Multiple agents in parallel:** give each agent its own git worktree + branch
  so they don't clobber each other:

  ```bash
  .claude/scripts/agent-worktree.sh new  featureA     # ../revolution-worktrees/featureA on branch agent/featureA
  .claude/scripts/agent-worktree.sh list
  .claude/scripts/agent-worktree.sh pr   featureA "Feature A"   # push + open PR to main
  .claude/scripts/agent-worktree.sh rm   featureA
  ```

  Point each Claude Code agent's working directory at its worktree path. Each
  worktree auto-commits/pushes its **own** branch. Merge to `main` via PR.

  > Simplest alternative: if you'd rather all agents share `main`, they can —
  > the rebase-retry in auto-commit.sh handles the races. Worktrees are cleaner
  > when agents touch overlapping files.

---

## M4 mini (emulator machine) — one-time setup

### 1. Prerequisites

```bash
# Flutter + Xcode + Android Studio installed, then:
gh auth login          # or an SSH key / PAT — the mini must be able to pull
flutter doctor         # should be green for both Android toolchain and Xcode
```

### 2. Clone the repo

```bash
git clone https://github.com/trader26-tech/revolution.git
cd revolution
```

### 3. Start the sync loop

```bash
.claude/scripts/mini-sync.sh
```

That's the whole thing. It will:

1. **Boot the emulators for you** if none are running — first available AVD via
   `emulator`, first available iPhone via `xcrun simctl`. Already have them
   open? It uses those. (`AUTO_BOOT=0` to disable.)
2. Start `flutter run --machine` on each device and wait for the app to launch.
3. Poll GitHub every 5s; on each new commit → `git merge --ff-only` →
   `flutter pub get` if needed → reload **both** emulators.

Leave the terminal running. `Ctrl-C` stops both sessions and the emulator
processes cleanly.

> **Reload vs restart.** Dart-only changes get a **hot reload** (state kept).
> Changes under `frontend/pubspec*` or `frontend/android|ios/` get a **full
> restart**, because hot reload cannot apply them. A new *native plugin* still
> needs a real rebuild — restart `mini-sync.sh` for that.

### 4. Optional — run it automatically at login

So you never have to remember to start it:

```bash
.claude/scripts/install-mini-service.sh          # installs a launchd agent
tail -f ~/Library/Logs/revolution-mini-sync.out.log
```

`KeepAlive` restarts it if it ever dies. To change branch/poll settings, re-run
the installer with the env vars set. To remove it:

```bash
.claude/scripts/install-mini-service.sh uninstall
```

### Knobs (env vars)
| var | default | meaning |
|-----|---------|---------|
| `BRANCH` | `main` | branch to track (use `agent/foo` to watch one agent) |
| `POLL_SECONDS` | `5` | GitHub poll interval |
| `AUTO_BOOT` | `1` | `0` = don't boot emulators, only use running ones |
| `AVD_NAME` | first | which Android AVD to boot |
| `IOS_SIM_NAME` | first iPhone | which simulator to boot |
| `ANDROID_ID` | auto | force a device id if auto-detect misses it |
| `IOS_ID` | auto | same for the iOS sim |
| `RUN_TARGET` | `lib/main.dart` | entrypoint |
| `FLUTTER_ARGS` | — | extra args for `flutter run` (e.g. `--flavor dev`) |
| `STARTUP_WAIT` | `600` | seconds allowed for the first build |
| `NO_EMULATORS` | `0` | `1` = pull only, don't launch flutter (headless) |

Examples:
```bash
BRANCH=agent/featureA .claude/scripts/mini-sync.sh      # watch one agent's branch
POLL_SECONDS=3 .claude/scripts/mini-sync.sh             # faster polling
ANDROID_ID=emulator-5554 IOS_ID=<UDID> .claude/scripts/mini-sync.sh
```

### Why `--machine` (don't "simplify" this)

`mini-sync.sh` drives Flutter's **daemon JSON protocol**, not the interactive
`r` keypress. Plain `flutter run` disables its interactive keys when stdin is
not a TTY, so piping `r` into it from a script silently does nothing. The
daemon protocol (`app.restart` with `fullRestart:false`) is the supported way
to reload from a script and works fine over a pipe.

The script is also written for **bash 3.2**, which is what macOS ships — no
`${arr[@]}` under `set -u`, no `exec {fd}>` auto-fd redirects. Both are fatal
on a stock Mac.

---

## Flow, end to end

```
M5: agent edits code ─▶ Stop hook ─▶ auto-commit.sh ─▶ git push ─▶ GitHub
                                                                      │
M4 mini: mini-sync.sh polls every 5s ◀── git fetch ◀──────────────────┘
          │
          └─▶ git merge --ff-only ─▶ (pub get if needed) ─▶ hot reload Android + iOS
```

Change on the M5 shows up on both emulators within ~POLL_SECONDS + reload time.

## Gotchas
- **Never edit code on the mini.** It's a consumer; the sync uses `--ff-only`.
  If it diverges, the log says so and syncing stops until you reset it:
  `git reset --hard origin/<branch>`.
- Hot reload can't apply everything. The script auto-escalates to a full restart
  for `pubspec` and native changes, but a brand-new native plugin needs a real
  rebuild — restart `mini-sync.sh`.
- Both machines must be authed to GitHub (`gh auth status` / an SSH key or PAT).
- A **physically connected** iPhone/Android is deliberately ignored — device
  detection requires `"emulator":true`. Set `IOS_ID`/`ANDROID_ID` to target one.
- Nothing here is peer-to-peer. If the mini shows nothing, check GitHub first:
  did the M5 actually push? (`git log origin/main -1`)

## Troubleshooting on the mini

```bash
# What does Flutter see?
cd frontend && flutter devices

# Watch the loop when running as a service
tail -f ~/Library/Logs/revolution-mini-sync.out.log

# Run pull-only, no emulators — isolates "is it git or is it flutter?"
NO_EMULATORS=1 .claude/scripts/mini-sync.sh
```
