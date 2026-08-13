#!/usr/bin/env bash
#
# Safe APK install — never fails with "App not installed as package conflicts
# with an existing package".
#
# That error is Android refusing to install an APK whose SIGNATURE (or, more
# rarely, whose versionCode) differs from the copy already on the device — e.g.
# a debug-signed dev build over a release-signed one downloaded from the landing
# page, or two machines whose debug keystores differ. A plain `adb install -r`
# can't reconcile that; the only reliable fix is to remove the old package and
# install fresh.
#
# This script tries a normal reinstall first (fast, keeps app data). If — and
# ONLY if — that fails with a signature/duplicate conflict, it uninstalls the
# existing package and installs clean. Any other failure is surfaced as-is.
#
# Usage:
#   scripts/install-safe.sh [path/to.apk] [-s <device-serial>]
#
# Defaults to the debug APK and the first connected device.

set -uo pipefail

APK=""
SERIAL=""
PKG="com.revolution.revolution"

# --- args ---------------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    -s) SERIAL="$2"; shift 2 ;;
    -p) PKG="$2"; shift 2 ;;
    *) APK="$1"; shift ;;
  esac
done

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

[[ -n "$APK" ]] || APK="build/app/outputs/flutter-apk/app-debug.apk"
[[ -f "$APK" ]] || { echo "install-safe: APK not found: $APK" >&2; exit 1; }

# --- adb ----------------------------------------------------------------
ADB="adb"
command -v adb >/dev/null 2>&1 || \
  ADB="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-$HOME/Library/Android/sdk}}/platform-tools/adb"
[[ -x "$ADB" || "$ADB" == "adb" ]] || { echo "install-safe: adb not found" >&2; exit 1; }

DEV=()
[[ -n "$SERIAL" ]] && DEV=(-s "$SERIAL")

echo "install-safe: installing $APK …"

# 1) Fast path — reinstall keeping data (-r) and allow a version downgrade (-d).
OUT="$("$ADB" "${DEV[@]}" install -r -d "$APK" 2>&1)"
if printf '%s' "$OUT" | grep -q "Success"; then
  echo "install-safe: ✅ installed (kept app data)."
  exit 0
fi

# 2) Only auto-recover from a genuine conflict — a signature mismatch or a
#    duplicate package. Anything else (no space, aborted, bad APK) is a real
#    error the user should see, so don't blindly wipe the app for those.
if printf '%s' "$OUT" | grep -qiE "INSTALL_FAILED_UPDATE_INCOMPATIBLE|signatures do not match|INSTALL_FAILED_DUPLICATE_PACKAGE|INCONSISTENT_CERTIFICATES|INSTALL_FAILED_VERSION_DOWNGRADE"; then
  echo "install-safe: signature/version conflict detected — reinstalling clean."
  echo "install-safe: (this removes the old copy's app data; unavoidable for a signature change.)"
  "$ADB" "${DEV[@]}" uninstall "$PKG" >/dev/null 2>&1 || true
  OUT2="$("$ADB" "${DEV[@]}" install "$APK" 2>&1)"
  if printf '%s' "$OUT2" | grep -q "Success"; then
    echo "install-safe: ✅ installed clean."
    exit 0
  fi
  echo "install-safe: ❌ clean install still failed:" >&2
  printf '%s\n' "$OUT2" >&2
  exit 1
fi

# 3) Some other failure — surface it verbatim.
echo "install-safe: ❌ install failed:" >&2
printf '%s\n' "$OUT" >&2
exit 1
