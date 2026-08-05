#!/usr/bin/env bash
#
# One command to develop with live emulators.
#
#   ./dev.sh
#
# Boots the Android emulator + iOS simulator if they aren't already running,
# launches the app on both, then watches for changes. Every new commit — made
# here or pulled from GitHub — hot-reloads both emulators automatically.
#
# Ctrl-C stops everything cleanly.
#
# Options are passed straight through as env vars, e.g.:
#   BRANCH=agent/featureA ./dev.sh      # follow one agent's branch
#   POLL_SECONDS=2 ./dev.sh             # check for changes more often
#
# See .claude/SYNC_SETUP.md for the full list.

exec "$(dirname "$0")/.claude/scripts/mini-sync.sh" "$@"
