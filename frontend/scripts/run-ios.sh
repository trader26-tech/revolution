#!/usr/bin/env bash
# Fast, reliable iPhone deploy for Revolution.
#
# WHY THIS EXISTS: plain `flutter run -d <iphone>` fails on this project with a
# suppressed "Xcode build ... status code 255". The project uses Swift Package
# Manager (the CocoaPods Podfile is intentionally *.disabled), and Flutter's
# build pipeline doesn't pass `-allowProvisioningUpdates`, which Xcode now needs
# for first-time device provisioning. Direct xcodebuild + devicectl works every
# time. This script is that proven path in one command.
#
# Builds in RELEASE by default so the app launches straight from the HOME SCREEN
# — a DEBUG build shows iOS's "debug apps can only be launched from Flutter
# tooling" screen and needs `flutter attach`. Release just runs.
#
# Usage:  ./scripts/run-ios.sh            # release (tap-to-run, default)
#         ./scripts/run-ios.sh debug      # debug (needs `flutter attach` after)
# Prereqs (one-time): CocoaPods on PATH (see below), signing team set in Xcode.

set -euo pipefail

# Build config: Release (default) or Debug (pass "debug" as 2nd-ish arg).
CONFIG="Release"
CONFIG_DIR="Release-iphoneos"
for a in "$@"; do
  case "$a" in
    debug|Debug) CONFIG="Debug"; CONFIG_DIR="Debug-iphoneos" ;;
  esac
done

# CocoaPods lives in the user gem dir (installed against system Ruby 2.6 with
# pinned deps). Add it to PATH so any pod step works.
export PATH="$HOME/.gem/ruby/2.6.0/bin:$PATH"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# First non-"debug" arg is an optional explicit device id.
DEVICE=""
for a in "$@"; do
  case "$a" in debug|Debug) ;; *) DEVICE="$a"; break ;; esac
done
if [ -z "$DEVICE" ]; then
  DEVICE="$(flutter devices --machine 2>/dev/null \
    | python3 -c 'import sys,json;      \
        d=json.load(sys.stdin);         \
        ios=[x for x in d if x.get("targetPlatform","").startswith("ios") and not x.get("emulator")]; \
        print(ios[0]["id"] if ios else "")')"
fi

if [ -z "$DEVICE" ]; then
  echo "No iPhone found. Connect it (USB + unlock + Trust) and retry." >&2
  exit 1
fi
echo "▶ Target iPhone: $DEVICE   ($CONFIG)"

BUNDLE_ID="com.revolution.revolution.dev"

# ── Pre-flight: catch compile errors in ~2–5s instead of after a 60s Xcode
#    build. Skip with SKIP_ANALYZE=1. ────────────────────────────────────────
if [ "${SKIP_ANALYZE:-0}" != "1" ]; then
  echo "▶ Analyzing (fast fail on errors)…"
  ANALYZE_OUT="$(flutter analyze lib 2>&1 || true)"
  if grep -qE "^\s*error •" <<<"$ANALYZE_OUT"; then
    echo "✗ Analyze found errors — NOT building. Fix these:" >&2
    grep -E "error •" <<<"$ANALYZE_OUT" | head -12 >&2
    exit 2
  fi
  echo "  ✓ no analyzer errors"
fi

# ── Guard against concurrent/stale builds (peer Claude sessions lock the Xcode
#    build DB). Only clear if OUR script isn't the one holding it. ────────────
STALE="$(pgrep -f 'xcodebuild.*Runner' | grep -v $$ || true)"
if [ -n "$STALE" ]; then
  echo "▶ Clearing a stale/concurrent xcodebuild + build-DB lock…"
  echo "$STALE" | xargs kill 2>/dev/null || true
  sleep 1
fi
rm -rf ~/Library/Developer/Xcode/DerivedData/Runner-*/Build/Intermediates.noindex/XCBuildData 2>/dev/null || true

echo "▶ flutter pub get"
flutter pub get >/dev/null

# Release/profile need the Dart AOT snapshot assembled before Xcode links it.
# `flutter build ios` produces that and the App.framework; we then re-run
# xcodebuild with -allowProvisioningUpdates to sign for the device. (flutter's
# own build reports a benign "Failed to build" — the xcodebuild step below is
# what actually completes and signs it.)
if [ "$CONFIG" = "Release" ]; then
  echo "▶ flutter build ios --release (AOT + framework)…"
  # flutter's own iOS build reports a benign failure on this project; the
  # xcodebuild step below is what actually completes it. Fully detach its exit
  # code from the script (set -e / pipefail must not abort here) and just show a
  # few progress lines.
  ( flutter build ios --release --no-codesign 2>&1 || true ) \
    | grep -iE "Building|Xcode build done" || true
fi

# Pre-resolve the Swift Package graph. SPM intermittently fails with "Could not
# compute dependency graph / Failed to receive dependency graph response" when
# the graph is resolved concurrently; a standalone resolve first settles it.
echo "▶ Resolving Swift packages…"
xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner \
  -resolvePackageDependencies >/dev/null 2>&1 || true

# Build + sign, retrying on the transient SPM dependency-graph flake.
run_xcodebuild() {
  xcodebuild \
    -workspace ios/Runner.xcworkspace \
    -scheme Runner \
    -configuration "$CONFIG" \
    -destination "id=$DEVICE" \
    -allowProvisioningUpdates \
    build 2>&1
}

echo "▶ Building + signing (xcodebuild -allowProvisioningUpdates)…"
BUILD_OUT=""
# Disable errexit/pipefail around the retry loop so a failed attempt RETRIES
# instead of silently aborting the whole script (which left the deploy hanging
# at "Building + signing" with no output).
set +e
set +o pipefail
for attempt in 1 2 3; do
  BUILD_OUT="$(run_xcodebuild)"
  if grep -q "\*\* BUILD SUCCEEDED \*\*" <<<"$BUILD_OUT"; then
    echo "  ✓ BUILD SUCCEEDED (attempt $attempt)"
    break
  fi
  echo "  build attempt $attempt did not succeed; retrying…"
  sleep 3
done
set -e

if ! grep -q "\*\* BUILD SUCCEEDED \*\*" <<<"$BUILD_OUT"; then
  echo "✗ Xcode build failed after retries. Key errors:" >&2
  grep -iE "error:|damaged|does not contain a scheme|dependency graph" \
    <<<"$BUILD_OUT" | grep -v "export " | head -8 >&2
  exit 1
fi

# Locate the SIGNED, installable Runner.app. It can land in DerivedData OR in
# Flutter's build/ios dir depending on config; pick the first candidate that's a
# valid bundle (has a CFBundleIdentifier), so we never try to install the
# incomplete --no-codesign prebuild output.
APP=""
CANDIDATES=(
  $(find "$HOME/Library/Developer/Xcode/DerivedData" \
      -path "*/Build/Products/$CONFIG_DIR/Runner.app" -maxdepth 6 -type d 2>/dev/null)
  "build/ios/$CONFIG_DIR/Runner.app"
  "build/ios/iphoneos/Runner.app"
)
for cand in "${CANDIDATES[@]}"; do
  [ -d "$cand" ] || continue
  if /usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' \
       "$cand/Info.plist" >/dev/null 2>&1; then
    APP="$cand"
    break
  fi
done
if [ -z "$APP" ]; then
  echo "✗ Built but couldn't locate a valid signed Runner.app." >&2
  echo "  Looked in DerivedData/$CONFIG_DIR and build/ios/." >&2
  exit 1
fi
echo "▶ App: $APP"

echo "▶ Installing to iPhone…"
xcrun devicectl device install app --device "$DEVICE" "$APP"

echo "▶ Launching…"
xcrun devicectl device process launch --device "$DEVICE" "$BUNDLE_ID"

echo "✓ Revolution is running on the iPhone."
if [ "$CONFIG" = "Debug" ]; then
  echo "  (Debug build — for hot reload run: flutter attach -d $DEVICE)"
else
  echo "  (Release build — also launches by tapping the icon on the home screen.)"
fi
