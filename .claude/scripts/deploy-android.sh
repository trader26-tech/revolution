#!/usr/bin/env bash
#
# Auto-deploy the latest app build to the connected Android phone.
#
# Invoked by the Claude Code "Stop" hook after an agent finishes, so the phone
# always has the newest code. Best-effort and NON-BLOCKING:
#   • If no phone is connected, it exits quietly (never fails the turn).
#   • The actual build+install runs in the BACKGROUND (nohup) so the agent's
#     Stop isn't held for the ~1–2 min Gradle build.
#
# Target device defaults to the Vivo (10AEB43F7G002B2) but auto-falls-back to
# whatever single physical device is attached.

set -uo pipefail

PREFERRED_DEVICE="10AEB43F7G002B2"
ADB="$HOME/Library/Android/sdk/platform-tools/adb"
FRONTEND="$(git rev-parse --show-toplevel 2>/dev/null)/frontend"
LOG="/tmp/revolution-deploy.log"

[[ -x "$ADB" ]] || exit 0
[[ -d "$FRONTEND" ]] || exit 0

# Which device? Prefer the Vivo; else the only connected physical device.
device=""
if "$ADB" devices 2>/dev/null | grep -q "^${PREFERRED_DEVICE}[[:space:]]*device$"; then
  device="$PREFERRED_DEVICE"
else
  # A single online device (ignore 'emulator-*' offline/unauthorized lines).
  count="$("$ADB" devices 2>/dev/null | grep -cE "[[:space:]]device$")"
  if [[ "$count" == "1" ]]; then
    device="$("$ADB" devices 2>/dev/null | grep -E "[[:space:]]device$" | awk '{print $1}')"
  fi
fi

# No usable device → nothing to do. Quiet success so the Stop hook is happy.
if [[ -z "$device" ]]; then
  exit 0
fi

# Build + install in the BACKGROUND so the agent isn't blocked. `flutter run`
# would hold a session; `flutter install` just pushes the freshly-built APK and
# exits, which is what "always has the latest version" needs.
nohup bash -c "
  export PATH=\"\$HOME/.gem/ruby/2.6.0/bin:\$PATH\"
  cd '$FRONTEND' || exit 1
  echo \"[\$(date)] building + installing to $device\" >> '$LOG'
  if flutter build apk --debug >> '$LOG' 2>&1; then
    # Install via the safe installer, which auto-recovers from a signature/
    # version conflict (the 'App not installed as package conflicts with an
    # existing package' error) by uninstalling the old copy and installing
    # clean — so a debug build never gets stuck behind a differently-signed
    # (e.g. release, or another machine's) install.
    scripts/install-safe.sh -s '$device' >> '$LOG' 2>&1
  fi
  echo \"[\$(date)] done (exit \$?)\" >> '$LOG'
" >/dev/null 2>&1 &

# Tell the user it's deploying (shown in the UI).
echo "{\"systemMessage\": \"Deploying latest build to $device in the background (see /tmp/revolution-deploy.log)\"}"
exit 0
