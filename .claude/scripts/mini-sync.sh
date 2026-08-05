#!/usr/bin/env bash
#
# M4 mini: auto-pull + hot-reload sync loop.
#
# Runs on the Mac mini that hosts the Android + iOS emulators. It:
#   1. Starts a `flutter run` session on each target device (Android + iOS),
#      each with hot reload enabled.
#   2. Polls GitHub every POLL_SECONDS. When origin/<branch> moves ahead of
#      the local checkout, it pulls (fast-forward) and triggers a hot reload
#      on every running session by sending "r" to its input pipe.
#
# Nothing here talks to the M5 directly — GitHub is the only middleman.
#
# Usage:
#   .claude/scripts/mini-sync.sh                 # sync branch 'main'
#   BRANCH=agent/foo .claude/scripts/mini-sync.sh
#
# Env knobs:
#   BRANCH        branch to track                 (default: main)
#   POLL_SECONDS  how often to check GitHub        (default: 5)
#   ANDROID_ID    flutter device id for Android    (default: auto-detect "emulator-")
#   IOS_ID        flutter device id for iOS sim    (default: auto-detect)
#   RUN_TARGET    entrypoint passed to flutter run (default: lib/main.dart)
#   NO_EMULATORS  set to 1 to only pull, no flutter run (headless sync)

set -uo pipefail

BRANCH="${BRANCH:-main}"
POLL_SECONDS="${POLL_SECONDS:-5}"
RUN_TARGET="${RUN_TARGET:-lib/main.dart}"
NO_EMULATORS="${NO_EMULATORS:-0}"

# --- locate the repo + flutter app --------------------------------------
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "${REPO_ROOT}" ]]; then
  echo "mini-sync: run this from inside the repo checkout." >&2
  exit 1
fi
cd "${REPO_ROOT}"

APP_DIR="${REPO_ROOT}/frontend"   # Flutter app lives in frontend/
if [[ ! -f "${APP_DIR}/pubspec.yaml" ]]; then
  echo "mini-sync: no Flutter app at ${APP_DIR} (pubspec.yaml missing)." >&2
  exit 1
fi

# Where we keep the input pipes + logs for each flutter run session.
STATE_DIR="${TMPDIR:-/tmp}/mini-sync-$$"
mkdir -p "${STATE_DIR}"
SESSIONS=()   # names of active flutter sessions

log() { echo "[mini-sync $(date '+%H:%M:%S')] $*"; }

cleanup() {
  log "shutting down..."
  for name in "${SESSIONS[@]}"; do
    local_pipe="${STATE_DIR}/${name}.in"
    # 'q' quits a flutter run session cleanly.
    [[ -p "${local_pipe}" ]] && echo "q" > "${local_pipe}" 2>/dev/null || true
  done
  sleep 2
  # Kill anything still alive.
  for name in "${SESSIONS[@]}"; do
    pid_file="${STATE_DIR}/${name}.pid"
    [[ -f "${pid_file}" ]] && kill "$(cat "${pid_file}")" 2>/dev/null || true
  done
  rm -rf "${STATE_DIR}"
}
trap cleanup EXIT INT TERM

# --- start one flutter run session on a device --------------------------
# start_session <name> <device-id>
start_session() {
  local name="$1" device="$2"
  local pipe="${STATE_DIR}/${name}.in"
  local logf="${STATE_DIR}/${name}.log"
  mkfifo "${pipe}"

  log "starting flutter run on ${name} (device: ${device})"
  # Keep the pipe open for writing via fd so it doesn't EOF between reloads.
  (
    cd "${APP_DIR}"
    # Read commands (r/R/q) from the pipe on stdin.
    flutter run -d "${device}" -t "${RUN_TARGET}" < "${pipe}" > "${logf}" 2>&1
  ) &
  echo "$!" > "${STATE_DIR}/${name}.pid"
  # Hold the pipe open so writers never see EOF.
  exec {fd}> "${pipe}"
  eval "FD_${name}=${fd}"
  SESSIONS+=("${name}")
}

# reload_session <name>  — send hot reload ("r") to a session.
reload_session() {
  local name="$1"
  local pipe="${STATE_DIR}/${name}.in"
  [[ -p "${pipe}" ]] && printf 'r\n' > "${pipe}" && log "hot-reloaded ${name}"
}

# --- detect emulator/simulator device ids -------------------------------
detect_devices() {
  local devices
  devices="$(cd "${APP_DIR}" && flutter devices --machine 2>/dev/null || echo '[]')"

  # Android emulator id (starts with "emulator-") unless overridden.
  if [[ -z "${ANDROID_ID:-}" ]]; then
    ANDROID_ID="$(echo "${devices}" \
      | grep -oE '"id"[^,]*"(emulator-[0-9]+)"' \
      | grep -oE 'emulator-[0-9]+' | head -1 || true)"
  fi
  # iOS simulator id (targetPlatform ios + emulator). Fallback: parse text.
  if [[ -z "${IOS_ID:-}" ]]; then
    IOS_ID="$(cd "${APP_DIR}" && flutter devices 2>/dev/null \
      | grep -iE 'ios|iphone|ipad' | grep -iE 'simulator|mobile' \
      | sed -E 's/.*• ([0-9A-Fa-f-]{8,}) •.*/\1/' | head -1 || true)"
  fi
}

# --- boot the emulator sessions -----------------------------------------
if [[ "${NO_EMULATORS}" != "1" ]]; then
  detect_devices
  if [[ -n "${ANDROID_ID:-}" ]]; then
    start_session "android" "${ANDROID_ID}"
  else
    log "no Android emulator detected — start one, or set ANDROID_ID. Skipping."
  fi
  if [[ -n "${IOS_ID:-}" ]]; then
    start_session "ios" "${IOS_ID}"
  else
    log "no iOS simulator detected — boot one, or set IOS_ID. Skipping."
  fi
  log "waiting 10s for sessions to build+launch before first reload..."
  sleep 10
else
  log "NO_EMULATORS=1 — pull-only mode, no flutter sessions."
fi

# --- the sync loop ------------------------------------------------------
log "tracking origin/${BRANCH}, polling every ${POLL_SECONDS}s. Ctrl-C to stop."
while true; do
  git fetch --quiet origin "${BRANCH}" 2>/dev/null || { sleep "${POLL_SECONDS}"; continue; }

  LOCAL="$(git rev-parse HEAD 2>/dev/null || echo none)"
  REMOTE="$(git rev-parse "origin/${BRANCH}" 2>/dev/null || echo none)"

  if [[ "${LOCAL}" != "${REMOTE}" && "${REMOTE}" != "none" ]]; then
    log "new commit on origin/${BRANCH} (${REMOTE:0:8}). Pulling..."
    # Fast-forward only — the mini is a consumer, it should never diverge.
    if git merge --ff-only "origin/${BRANCH}" >/dev/null 2>&1; then
      # If Dart deps changed, refresh packages before reloading.
      if git diff --name-only "${LOCAL}" "${REMOTE}" | grep -q '^frontend/pubspec'; then
        log "pubspec changed — running flutter pub get"
        (cd "${APP_DIR}" && flutter pub get >/dev/null 2>&1 || true)
      fi
      for name in "${SESSIONS[@]}"; do
        reload_session "${name}"
      done
      log "synced to ${REMOTE:0:8}."
    else
      log "local checkout diverged from origin/${BRANCH}; can't fast-forward."
      log "  fix on the mini with: git reset --hard origin/${BRANCH}"
    fi
  fi
  sleep "${POLL_SECONDS}"
done
