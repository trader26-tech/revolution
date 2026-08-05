#!/usr/bin/env bash
#
# M4 mini: auto-pull + hot-reload sync loop.
#
# Runs on the Mac mini that hosts the Android emulator + iOS simulator. It:
#   1. Optionally boots an Android AVD and an iOS simulator.
#   2. Starts a `flutter run --machine` session per device. --machine speaks
#      Flutter's daemon JSON protocol over stdin/stdout, which is the only
#      reliable way to trigger a reload from a script: plain `flutter run`
#      disables its interactive r/R keys when stdin is not a TTY.
#   3. Polls GitHub every POLL_SECONDS. When origin/<branch> moves ahead, it
#      fast-forward merges and sends app.restart to every session —
#      fullRestart:false (hot reload) normally, fullRestart:true when native
#      code or deps changed, since hot reload can't pick those up.
#
# Nothing talks to the M5 directly — GitHub is the only middleman.
#
# Written for bash 3.2 (what macOS ships). No associative arrays, no {fd}
# redirects, no `${arr[@]}` under `set -u`.
#
# Usage:
#   .claude/scripts/mini-sync.sh
#   BRANCH=agent/foo .claude/scripts/mini-sync.sh
#
# Env knobs:
#   BRANCH         branch to track                  (default: main)
#   POLL_SECONDS   how often to check GitHub         (default: 5)
#   ANDROID_ID     flutter device id for Android     (default: auto-detect)
#   IOS_ID         flutter device id for iOS sim     (default: auto-detect)
#   RUN_TARGET     entrypoint for flutter run        (default: lib/main.dart)
#   FLUTTER_ARGS   extra args for flutter run        (default: empty)
#   AUTO_BOOT      1 = boot emulators if none found  (default: 1)
#   AVD_NAME       AVD to boot                       (default: first available)
#   IOS_SIM_NAME   simulator to boot                 (default: first booted, else "iPhone")
#   STARTUP_WAIT   seconds to wait for first build   (default: 600)
#   NO_EMULATORS   1 = pull only, no flutter run     (default: 0)

set -uo pipefail

BRANCH="${BRANCH:-main}"
POLL_SECONDS="${POLL_SECONDS:-5}"
RUN_TARGET="${RUN_TARGET:-lib/main.dart}"
FLUTTER_ARGS="${FLUTTER_ARGS:-}"
AUTO_BOOT="${AUTO_BOOT:-1}"
STARTUP_WAIT="${STARTUP_WAIT:-600}"
NO_EMULATORS="${NO_EMULATORS:-0}"
ANDROID_ID="${ANDROID_ID:-}"
IOS_ID="${IOS_ID:-}"
AVD_NAME="${AVD_NAME:-}"
IOS_SIM_NAME="${IOS_SIM_NAME:-}"

log() { echo "[mini-sync $(date '+%H:%M:%S')] $*"; }
die() { echo "[mini-sync] error: $*" >&2; exit 1; }

# --- locate the repo + flutter app --------------------------------------
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
[[ -n "${REPO_ROOT}" ]] || die "run this from inside the repo checkout."
cd "${REPO_ROOT}"

APP_DIR="${REPO_ROOT}/frontend"
[[ -f "${APP_DIR}/pubspec.yaml" ]] || die "no Flutter app at ${APP_DIR} (pubspec.yaml missing)."

# Find Flutter even when it isn't on PATH — a plain double-click / launchd
# agent / fresh terminal often won't have it, and "flutter: not found" is the
# single most common reason this script appears to do nothing.
if ! command -v flutter >/dev/null 2>&1; then
  for candidate in \
    "${FLUTTER_ROOT:-}/bin" \
    "${HOME}/flutter/bin" \
    "${HOME}/development/flutter/bin" \
    "${HOME}/fvm/default/bin" \
    "/opt/homebrew/bin" \
    "/usr/local/bin"
  do
    if [[ -n "${candidate}" && -x "${candidate}/flutter" ]]; then
      PATH="${candidate}:${PATH}"
      export PATH
      log "found flutter at ${candidate}/flutter"
      break
    fi
  done
fi
command -v flutter >/dev/null 2>&1 \
  || die "flutter not found. Install it, or set FLUTTER_ROOT=/path/to/flutter."

# Session bookkeeping. bash 3.2 has no associative arrays, so sessions are a
# space-separated list of names and per-session state lives in files.
STATE_DIR="${TMPDIR:-/tmp}/mini-sync-$$"
mkdir -p "${STATE_DIR}"
SESSIONS=""

CLEANED_UP=0
cleanup() {
  [[ "${CLEANED_UP}" == "1" ]] && return 0
  CLEANED_UP=1
  log "shutting down..."
  for name in ${SESSIONS}; do
    pipe="${STATE_DIR}/${name}.in"
    app_id="$(cat "${STATE_DIR}/${name}.appid" 2>/dev/null || true)"
    if [[ -p "${pipe}" && -n "${app_id}" ]]; then
      printf '[{"id":999,"method":"app.stop","params":{"appId":"%s"}}]\n' \
        "${app_id}" > "${pipe}" 2>/dev/null || true
    fi
  done
  sleep 2
  # Close the fds holding the pipes open, then kill anything still alive.
  # Braces matter: on a bare `exec`, a trailing 2>/dev/null would apply to the
  # shell permanently and silence every later error. Scope it to the group.
  { exec 3>&-; } 2>/dev/null || true
  { exec 4>&-; } 2>/dev/null || true
  for name in ${SESSIONS}; do
    pid_file="${STATE_DIR}/${name}.pid"
    [[ -f "${pid_file}" ]] && kill "$(cat "${pid_file}")" 2>/dev/null || true
  done
  rm -rf "${STATE_DIR}"
}
# A bare `trap cleanup TERM` would tear down the sessions and then *resume*
# the poll loop — a zombie sync with nothing to reload. Signals must exit.
on_signal() { cleanup; exit 130; }
trap cleanup EXIT
trap on_signal INT TERM HUP

# --- booting emulators --------------------------------------------------
boot_android() {
  command -v emulator >/dev/null 2>&1 || {
    log "no 'emulator' on PATH — can't auto-boot Android. Start an AVD manually."
    return 1
  }
  local avd="${AVD_NAME}"
  if [[ -z "${avd}" ]]; then
    avd="$(emulator -list-avds 2>/dev/null | head -1)"
  fi
  [[ -n "${avd}" ]] || { log "no AVD configured — create one in Android Studio."; return 1; }

  log "booting Android AVD '${avd}'..."
  nohup emulator -avd "${avd}" >"${STATE_DIR}/emulator.log" 2>&1 &
  if command -v adb >/dev/null 2>&1; then
    adb wait-for-device >/dev/null 2>&1 || true
    # Wait for the framework to finish booting, not just the device node.
    local i=0
    while [[ ${i} -lt 120 ]]; do
      [[ "$(adb shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" == "1" ]] && break
      sleep 2; i=$((i + 1))
    done
  else
    sleep 45
  fi
  log "Android emulator up."
}

boot_ios() {
  command -v xcrun >/dev/null 2>&1 || { log "no xcrun — skipping iOS."; return 1; }
  # Already booted? Nothing to do.
  if xcrun simctl list devices booted 2>/dev/null | grep -q Booted; then
    return 0
  fi
  local udid
  if [[ -n "${IOS_SIM_NAME}" ]]; then
    udid="$(xcrun simctl list devices available 2>/dev/null \
      | grep -F "${IOS_SIM_NAME}" | head -1 \
      | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/')"
  else
    udid="$(xcrun simctl list devices available 2>/dev/null \
      | grep -E '^\s+iPhone' | head -1 \
      | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/')"
  fi
  [[ -n "${udid}" ]] || { log "no available iPhone simulator found."; return 1; }

  log "booting iOS simulator ${udid}..."
  xcrun simctl boot "${udid}" >/dev/null 2>&1 || true
  open -a Simulator >/dev/null 2>&1 || true
  local i=0
  while [[ ${i} -lt 60 ]]; do
    xcrun simctl list devices booted 2>/dev/null | grep -q "${udid}" && break
    sleep 2; i=$((i + 1))
  done
  log "iOS simulator up."
}

# --- detect device ids --------------------------------------------------
# Emit one "id<TAB>platform<TAB>emulator" row per device.
#
# Do NOT try to regex the raw --machine output: it is pretty-printed across
# many lines AND each device carries a nested "capabilities" object, so
# brace-matching grabs the wrong braces and finds no "id" at all. Parse the
# JSON properly, and fall back to the human-readable table if python3 is
# missing (there, an iOS *simulator* is the row whose sdk is a CoreSimulator
# runtime — a physically attached iPhone reports a real iOS version instead).
parse_devices() {
  local raw parsed
  raw="$(cd "${APP_DIR}" && flutter devices --machine 2>/dev/null || echo '[]')"
  parsed=""

  if command -v python3 >/dev/null 2>&1; then
    parsed="$(printf '%s' "${raw}" | python3 -c '
import sys, json
try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(1)
for d in data:
    print("%s\t%s\t%s" % (d.get("id",""), d.get("targetPlatform",""),
                          "true" if d.get("emulator") else "false"))
' 2>/dev/null)"
  fi

  if [[ -z "${parsed}" ]]; then
    local text
    text="$(cd "${APP_DIR}" && flutter devices 2>/dev/null | grep '•' || true)"
    local a i
    a="$(printf '%s\n' "${text}" | grep -oE 'emulator-[0-9]+' | head -1)"
    i="$(printf '%s\n' "${text}" | grep 'CoreSimulator' \
         | sed -E 's/.*• ([0-9A-Fa-f-]{36}) •.*/\1/' | head -1)"
    [[ -n "${a}" ]] && parsed="${a}	android	true"
    [[ -n "${i}" ]] && parsed="${parsed}
${i}	ios	true"
  fi
  printf '%s' "${parsed}"
}

# Require emulator=true so a physically connected phone is never hijacked —
# override with ANDROID_ID / IOS_ID if you actually want a real device.
detect_devices() {
  local rows
  rows="$(parse_devices)"
  if [[ -z "${ANDROID_ID}" ]]; then
    ANDROID_ID="$(printf '%s\n' "${rows}" \
      | awk -F'\t' '$2 ~ /^android/ && $3=="true" {print $1; exit}')"
  fi
  if [[ -z "${IOS_ID}" ]]; then
    IOS_ID="$(printf '%s\n' "${rows}" \
      | awk -F'\t' '$2=="ios" && $3=="true" {print $1; exit}')"
  fi
}

# --- flutter daemon sessions --------------------------------------------
# start_session <name> <device-id> <fd>
# The fd is held open on the FIFO so the daemon's stdin never sees EOF
# between reloads. bash 3.2 needs literal fd numbers here.
start_session() {
  name="$1"; device="$2"; fd="$3"
  pipe="${STATE_DIR}/${name}.in"
  logf="${STATE_DIR}/${name}.log"
  mkfifo "${pipe}"

  log "starting flutter run --machine on ${name} (device: ${device})"
  (
    cd "${APP_DIR}" || exit 1
    # shellcheck disable=SC2086
    flutter run --machine -d "${device}" -t "${RUN_TARGET}" ${FLUTTER_ARGS} \
      < "${pipe}" > "${logf}" 2>&1
  ) &
  echo "$!" > "${STATE_DIR}/${name}.pid"

  # Opening a FIFO for write blocks until the reader (above) opens it.
  case "${fd}" in
    3) exec 3> "${pipe}" ;;
    4) exec 4> "${pipe}" ;;
    *) die "unsupported fd ${fd}" ;;
  esac

  case " ${SESSIONS} " in
    *" ${name} "*) : ;;                       # already tracked (this is a restart)
    *) SESSIONS="${SESSIONS} ${name}" ;;
  esac
}

# Which literal fd each session's pipe is held open on. bash 3.2 has no
# associative arrays and no {fd} auto-allocation, so these are fixed.
fd_for_name() {
  case "$1" in
    android) echo 3 ;;
    ios)     echo 4 ;;
    *)       echo "" ;;
  esac
}

session_alive() {
  local pid
  pid="$(cat "${STATE_DIR}/$1.pid" 2>/dev/null || true)"
  [[ -n "${pid}" ]] && kill -0 "${pid}" 2>/dev/null
}

# A `flutter run` session dies on its own more often than you'd think — the
# emulator is closed and reopened, the device sleeps, adb drops out ("Lost
# connection to device"). Without this the loop keeps cheerfully sending
# reloads into a dead pipe and that emulator silently serves a stale build
# forever. Bring it back instead.
restart_session() {
  local name="$1" fd dev now last
  fd="$(fd_for_name "${name}")"
  [[ -n "${fd}" ]] || return 1

  # Back off so a device that is gone for good doesn't get hammered every tick.
  now="$(date +%s)"
  last="$(cat "${STATE_DIR}/${name}.retry" 2>/dev/null || echo 0)"
  [[ $(( now - last )) -lt ${RESTART_BACKOFF} ]] && return 1
  echo "${now}" > "${STATE_DIR}/${name}.retry"

  log "${name} session is gone — restarting it."
  case "${fd}" in
    3) { exec 3>&-; } 2>/dev/null || true ;;
    4) { exec 4>&-; } 2>/dev/null || true ;;
  esac
  # Remove the log too, not just the pipe/appid/pid. The replacement session
  # opens it with ">", which truncates in place — and a dying process that
  # still holds the old fd keeps writing at its previous offset, leaving NUL
  # padding plus stale events. That is what makes grep call the file binary
  # and what lets an old appId out-live the session it belonged to.
  rm -f "${STATE_DIR}/${name}.in" "${STATE_DIR}/${name}.appid" \
        "${STATE_DIR}/${name}.pid" "${STATE_DIR}/${name}.log"

  # Re-detect: a restarted emulator can come back with a different id.
  ANDROID_ID="${ANDROID_ID_PINNED}"
  IOS_ID="${IOS_ID_PINNED}"
  detect_devices
  case "${name}" in
    android) dev="${ANDROID_ID}" ;;
    ios)     dev="${IOS_ID}" ;;
  esac
  if [[ -z "${dev}" ]]; then
    log "  ${name}: no device visible yet — will retry in ${RESTART_BACKOFF}s."
    return 1
  fi

  start_session "${name}" "${dev}" "${fd}"
  wait_for_app "${name}" || { log "  ${name}: did not come back up."; return 1; }
  return 0
}

# wait_for_app <name> — block until the daemon reports the app started,
# capturing its appId. Returns 1 on timeout.
wait_for_app() {
  name="$1"
  logf="${STATE_DIR}/${name}.log"
  waited=0
  log "waiting for ${name} to build + launch (up to ${STARTUP_WAIT}s)..."
  while [[ ${waited} -lt ${STARTUP_WAIT} ]]; do
    # -a on every read of this log: Android's logcat interleaves non-UTF8
    # bytes, and without it grep prints "Binary file ... matches" instead of
    # the match. That string then gets stored as the appId and every reload is
    # addressed to a device that doesn't exist — silently, forever.
    if grep -a -q '"event":"app.started"' "${logf}" 2>/dev/null; then
      app_id="$(grep -a -o '"appId":"[^"]*"' "${logf}" | head -1 | cut -d'"' -f4)"
      if [[ -n "${app_id}" ]]; then
        echo "${app_id}" > "${STATE_DIR}/${name}.appid"
        log "${name} running (appId ${app_id})."
        return 0
      fi
    fi
    # Bail early if the session died.
    pid="$(cat "${STATE_DIR}/${name}.pid" 2>/dev/null || echo)"
    if [[ -n "${pid}" ]] && ! kill -0 "${pid}" 2>/dev/null; then
      log "${name} session exited during startup. Last lines:"
      tail -5 "${logf}" >&2 2>/dev/null || true
      return 1
    fi
    sleep 3; waited=$((waited + 3))
  done
  log "${name} did not report app.started within ${STARTUP_WAIT}s. Last lines:"
  tail -5 "${logf}" >&2 2>/dev/null || true
  return 1
}

# reload_session <name> <full:0|1>
#
# Sending the request is NOT proof it worked: if the tree has a compile error,
# the daemon still answers, with code!=0 ("DevFS synchronization failed") and
# the emulator silently keeps running the last good build. Reporting success on
# a successful *write* would hide exactly the case you most need to know about,
# so wait for the reply and surface the compiler's complaint.
reload_session() {
  name="$1"; full="$2"
  pipe="${STATE_DIR}/${name}.in"
  logf="${STATE_DIR}/${name}.log"
  app_id="$(cat "${STATE_DIR}/${name}.appid" 2>/dev/null || true)"
  [[ -p "${pipe}" && -n "${app_id}" ]] || return 0

  REQ_ID=$((REQ_ID + 1))
  if [[ "${full}" == "1" ]]; then
    kind="restart"; flag="true"
  else
    kind="reload"; flag="false"
  fi
  # fd 3/4 keep the pipe open, so this write can't EOF the daemon.
  printf '[{"id":%d,"method":"app.restart","params":{"appId":"%s","fullRestart":%s,"pause":false,"reason":"manual"}}]\n' \
    "${REQ_ID}" "${app_id}" "${flag}" > "${pipe}" 2>/dev/null || return 0

  # Wait for this request's reply (RELOAD_TIMEOUT seconds, then give up).
  reply=""
  waited=0
  while [[ ${waited} -lt ${RELOAD_TIMEOUT} ]]; do
    reply="$(grep -a -oE "\{\"id\":${REQ_ID},\"result\":\{[^}]*\}" "${logf}" 2>/dev/null | tail -1)"
    [[ -n "${reply}" ]] && break
    sleep 1; waited=$((waited + 1))
  done

  if [[ -z "${reply}" ]]; then
    log "hot ${kind} → ${name}: sent, no reply in ${RELOAD_TIMEOUT}s"
    return 0
  fi

  code="$(printf '%s' "${reply}" | grep -oE '"code":[0-9]+' | cut -d: -f2)"
  msg="$(printf '%s' "${reply}" | sed -E 's/.*"message":"([^"]*)".*/\1/')"
  if [[ "${code}" == "0" ]]; then
    log "hot ${kind} → ${name}: ${msg}"
  else
    log "hot ${kind} → ${name} FAILED: ${msg}"
    # Show the first real compile error — that is almost always the cause.
    firstErr="$(grep -a -E '^lib/.*: Error:' "${logf}" 2>/dev/null | tail -1)"
    [[ -n "${firstErr}" ]] && log "  ${firstErr}"
    log "  ${name} is still running the last build that compiled."
  fi
}
REQ_ID=0
RELOAD_TIMEOUT="${RELOAD_TIMEOUT:-30}"
RESTART_BACKOFF="${RESTART_BACKOFF:-30}"
# Remember any explicit device pins so re-detection after a restart doesn't
# quietly wander onto a different device than the one you asked for.
ANDROID_ID_PINNED="${ANDROID_ID}"
IOS_ID_PINNED="${IOS_ID}"

# --- boot everything ----------------------------------------------------
if [[ "${NO_EMULATORS}" != "1" ]]; then
  detect_devices
  if [[ "${AUTO_BOOT}" == "1" ]]; then
    [[ -z "${ANDROID_ID}" ]] && boot_android
    [[ -z "${IOS_ID}" ]] && boot_ios
    detect_devices
  fi

  if [[ -n "${ANDROID_ID}" ]]; then
    start_session "android" "${ANDROID_ID}" 3
  else
    log "no Android emulator detected — start an AVD, or set ANDROID_ID. Skipping."
  fi
  if [[ -n "${IOS_ID}" ]]; then
    start_session "ios" "${IOS_ID}" 4
  else
    log "no iOS simulator detected — boot one, or set IOS_ID. Skipping."
  fi

  [[ -n "${SESSIONS// /}" ]] || die "no devices to run on. Boot an emulator and retry."

  for name in ${SESSIONS}; do
    wait_for_app "${name}" || log "${name} won't receive reloads."
  done
else
  log "NO_EMULATORS=1 — pull-only mode, no flutter sessions."
fi

# --- the sync loop ------------------------------------------------------
log "tracking origin/${BRANCH}, polling every ${POLL_SECONDS}s. Ctrl-C to stop."
LAST_HEAD="$(git rev-parse HEAD 2>/dev/null || echo none)"

while true; do
  # Revive any session that has died, before deciding what to reload — a dead
  # session would otherwise sit there stale while the log claims it reloaded.
  for name in ${SESSIONS}; do
    session_alive "${name}" || restart_session "${name}" || true
  done

  # Pull anything new from GitHub. A failed fetch (offline, laptop asleep) is
  # not fatal — local commits below should still trigger a reload.
  if git fetch --quiet origin "${BRANCH}" 2>/dev/null; then
    LOCAL="$(git rev-parse HEAD 2>/dev/null || echo none)"
    REMOTE="$(git rev-parse "origin/${BRANCH}" 2>/dev/null || echo none)"

    if [[ "${LOCAL}" != "${REMOTE}" && "${REMOTE}" != "none" ]]; then
      if git merge-base --is-ancestor "${LOCAL}" "${REMOTE}" 2>/dev/null; then
        log "new commit on origin/${BRANCH} (${REMOTE:0:8}). Pulling..."
        git merge --ff-only "origin/${BRANCH}" >/dev/null 2>&1 \
          || log "fast-forward failed — fix with: git reset --hard origin/${BRANCH}"
      elif git merge-base --is-ancestor "${REMOTE}" "${LOCAL}" 2>/dev/null; then
        : # We're ahead of origin — normal on the code machine, nothing to pull.
      else
        log "local and origin/${BRANCH} have diverged."
        log "  fix with: git reset --hard origin/${BRANCH}"
      fi
    fi
  fi

  # Reload whenever HEAD moved, whatever moved it — a pull from GitHub OR a
  # local commit made right here. That way this works unchanged on the code
  # machine (agents commit locally) and on the mini (commits arrive by pull).
  HEAD_NOW="$(git rev-parse HEAD 2>/dev/null || echo none)"
  if [[ "${HEAD_NOW}" != "${LAST_HEAD}" && "${HEAD_NOW}" != "none" ]]; then
    CHANGED="$(git diff --name-only "${LAST_HEAD}" "${HEAD_NOW}" 2>/dev/null || true)"
    FULL=0
    # Dart deps changed → refresh packages; a hot reload won't cut it.
    if printf '%s' "${CHANGED}" | grep -q '^frontend/pubspec'; then
      log "pubspec changed — running flutter pub get"
      (cd "${APP_DIR}" && flutter pub get >/dev/null 2>&1 || true)
      FULL=1
    fi
    # Native code changed → hot reload can't apply it either.
    if printf '%s' "${CHANGED}" | grep -qE '^frontend/(android|ios)/'; then
      log "native code changed — full restart (a rebuild may still be needed)"
      FULL=1
    fi
    # Skip pure backend/docs commits — no point reloading the UI for those.
    if printf '%s' "${CHANGED}" | grep -q '^frontend/'; then
      for name in ${SESSIONS}; do
        reload_session "${name}" "${FULL}"
      done
      log "synced to ${HEAD_NOW:0:8}."
    else
      log "${HEAD_NOW:0:8} touched no frontend files — skipping reload."
    fi
    LAST_HEAD="${HEAD_NOW}"
  fi
  sleep "${POLL_SECONDS}"
done
