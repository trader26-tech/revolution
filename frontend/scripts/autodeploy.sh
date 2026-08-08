#!/usr/bin/env bash
# Auto-deploy Revolution to the iPhone on every save.
#
# Watches lib/ for .dart changes → rebuilds RELEASE → installs + launches on the
# phone. Release so it runs standalone (debug builds crash on iOS without
# tooling). Pre-flight analyze so compile errors fail in seconds, never after a
# slow Xcode build. Coalesces rapid saves so it never stacks builds.
#
# Usage:  ./scripts/autodeploy.sh
# Stop:   Ctrl-C
#
# The whole point: you save, you look at your phone. No manual push, no babysit.

set -uo pipefail
export PATH="$HOME/.gem/ruby/2.6.0/bin:$PATH"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

DEPLOY="./scripts/run-ios.sh"          # release by default
WATCHER="dart run scripts/watch_lib.dart"

BUILDING=0        # 1 while a deploy is in flight
QUEUED=0          # 1 if a change arrived during a build → run once more after

deploy() {
  BUILDING=1
  local start=$SECONDS
  echo ""
  echo "──────────────────────────────────────────────"
  echo "⏳  $(date '+%H:%M:%S')  Building + deploying to iPhone…"
  if $DEPLOY; then
    local secs=$(( SECONDS - start ))
    echo "✅  On your phone in ${secs}s. Tap the icon (or it's already up)."
  else
    local code=$?
    if [ "$code" = "2" ]; then
      echo "❌  Compile error — fix it above, save again. (No build wasted.)"
    else
      echo "❌  Deploy failed (exit $code). See errors above."
    fi
  fi
  BUILDING=0
  # If a save landed mid-build, run exactly one more pass to catch it.
  if [ "$QUEUED" = "1" ]; then
    QUEUED=0
    deploy
  fi
}

request_deploy() {
  if [ "$BUILDING" = "1" ]; then
    QUEUED=1                          # coalesce — one more build after this one
    echo "↻  change noted — will rebuild after the current one finishes."
  else
    deploy
  fi
}

echo "🚀  Auto-deploy watching $ROOT/lib"
echo "    Save any .dart file → it lands on your phone. Ctrl-C to stop."

# Initial deploy so the phone is current the moment we start.
request_deploy

# React to each CHANGED line from the watcher.
$WATCHER | while IFS= read -r line; do
  case "$line" in
    CHANGED) request_deploy ;;
    WATCHING*) echo "👀  $line" ;;
  esac
done
