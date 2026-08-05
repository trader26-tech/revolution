#!/usr/bin/env bash
#
# Install mini-sync.sh as a launchd LaunchAgent on the M4 mini, so the sync
# loop starts at login and restarts itself if it ever dies.
#
# Run this ON THE MINI, from inside the repo checkout:
#   .claude/scripts/install-mini-service.sh
#   .claude/scripts/install-mini-service.sh uninstall
#
# Env knobs are baked into the plist at install time — re-run to change them:
#   BRANCH=agent/foo .claude/scripts/install-mini-service.sh
#
# Logs land in ~/Library/Logs/revolution-mini-sync.{out,err}.log

set -uo pipefail

LABEL="com.revolution.mini-sync"
PLIST="${HOME}/Library/LaunchAgents/${LABEL}.plist"
LOG_OUT="${HOME}/Library/Logs/revolution-mini-sync.out.log"
LOG_ERR="${HOME}/Library/Logs/revolution-mini-sync.err.log"

if [[ "${1:-}" == "uninstall" ]]; then
  launchctl bootout "gui/$(id -u)/${LABEL}" 2>/dev/null \
    || launchctl unload "${PLIST}" 2>/dev/null || true
  rm -f "${PLIST}"
  echo "uninstalled ${LABEL}."
  exit 0
fi

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
[[ -n "${REPO_ROOT}" ]] || { echo "run this from inside the repo checkout." >&2; exit 1; }

SCRIPT="${REPO_ROOT}/.claude/scripts/mini-sync.sh"
[[ -x "${SCRIPT}" ]] || chmod +x "${SCRIPT}"

BRANCH="${BRANCH:-main}"
POLL_SECONDS="${POLL_SECONDS:-5}"
AUTO_BOOT="${AUTO_BOOT:-1}"

# launchd agents get a minimal PATH — flutter/adb/emulator/xcrun won't be on it
# unless we pass the *current* PATH through explicitly.
CUR_PATH="${PATH}"

mkdir -p "${HOME}/Library/LaunchAgents" "${HOME}/Library/Logs"

cat > "${PLIST}" <<PLIST_EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>          <string>${LABEL}</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>${SCRIPT}</string>
  </array>
  <key>WorkingDirectory</key> <string>${REPO_ROOT}</string>
  <key>EnvironmentVariables</key>
  <dict>
    <key>PATH</key>         <string>${CUR_PATH}</string>
    <key>BRANCH</key>       <string>${BRANCH}</string>
    <key>POLL_SECONDS</key> <string>${POLL_SECONDS}</string>
    <key>AUTO_BOOT</key>    <string>${AUTO_BOOT}</string>
  </dict>
  <key>RunAtLoad</key>      <true/>
  <key>KeepAlive</key>      <true/>
  <key>ThrottleInterval</key><integer>30</integer>
  <key>StandardOutPath</key><string>${LOG_OUT}</string>
  <key>StandardErrorPath</key><string>${LOG_ERR}</string>
</dict>
</plist>
PLIST_EOF

# Reload cleanly if it was already installed.
launchctl bootout "gui/$(id -u)/${LABEL}" 2>/dev/null || true
if launchctl bootstrap "gui/$(id -u)" "${PLIST}" 2>/dev/null; then
  :
else
  launchctl load "${PLIST}" 2>/dev/null || {
    echo "failed to load ${PLIST} — load it manually with:" >&2
    echo "  launchctl bootstrap gui/$(id -u) ${PLIST}" >&2
    exit 1
  }
fi

echo "installed ${LABEL}"
echo "  repo:    ${REPO_ROOT}"
echo "  branch:  ${BRANCH}  (poll ${POLL_SECONDS}s, auto-boot ${AUTO_BOOT})"
echo "  logs:    ${LOG_OUT}"
echo
echo "watch it:   tail -f ${LOG_OUT}"
echo "stop it:    launchctl bootout gui/$(id -u)/${LABEL}"
echo "uninstall:  .claude/scripts/install-mini-service.sh uninstall"
