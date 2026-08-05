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

1. **Clone the repo** (once):
   ```bash
   git clone https://github.com/trader26-tech/revolution.git
   cd revolution
   ```
2. **Boot both emulators** so Flutter can see them:
   - Android: launch an AVD from Android Studio (or `emulator -avd <name>`).
   - iOS: `open -a Simulator` and boot an iPhone.
   - Confirm both show up: `cd frontend && flutter devices`
3. **Start the sync loop** from the repo root:
   ```bash
   .claude/scripts/mini-sync.sh
   ```
   It builds+launches the app on each detected device, then polls GitHub every
   5s. On every push from the M5 it fast-forward pulls and hot-reloads both.
   `flutter pub get` runs automatically when `pubspec` changes.

Leave that terminal running while you test. `Ctrl-C` quits both sessions cleanly.

### Knobs (env vars)
| var | default | meaning |
|-----|---------|---------|
| `BRANCH` | `main` | branch to track (use `agent/foo` to watch one agent) |
| `POLL_SECONDS` | `5` | GitHub poll interval |
| `ANDROID_ID` | auto | force a device id if auto-detect misses it |
| `IOS_ID` | auto | same for the iOS sim |
| `RUN_TARGET` | `lib/main.dart` | entrypoint |
| `NO_EMULATORS` | `0` | `1` = pull only, don't launch flutter (headless) |

Examples:
```bash
BRANCH=agent/featureA .claude/scripts/mini-sync.sh      # watch one agent's branch
POLL_SECONDS=3 .claude/scripts/mini-sync.sh             # faster polling
ANDROID_ID=emulator-5554 IOS_ID=<UDID> .claude/scripts/mini-sync.sh
```

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
  If it ever diverges, reset it: `git reset --hard origin/<branch>`.
- Hot reload can't apply some changes (new native deps, `main()` signature,
  global state). If a reload looks wrong, press `R` (capital) in the session for
  a full restart, or restart `mini-sync.sh`.
- Both machines must be authed to GitHub (`gh auth status` / an SSH key or PAT).
