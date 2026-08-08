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

echo "▶ flutter pub get"
flutter pub get >/dev/null

# Release/profile need the Dart AOT snapshot assembled before Xcode links it.
# `flutter build ios` produces that and the App.framework; we then re-run
# xcodebuild with -allowProvisioningUpdates to sign for the device.
if [ "$CONFIG" = "Release" ]; then
  echo "▶ flutter build ios --release (AOT + framework)…"
  flutter build ios --release --no-codesign 2>&1 \
    | grep -iE "Building|Xcode build done|error|Failed" | grep -v "export " || true
fi

echo "▶ Building + signing (xcodebuild -allowProvisioningUpdates)…"
xcodebuild \
  -workspace ios/Runner.xcworkspace \
  -scheme Runner \
  -configuration "$CONFIG" \
  -destination "id=$DEVICE" \
  -allowProvisioningUpdates \
  build 2>&1 | grep -E "\*\* BUILD|error:" | grep -v "export " || true

APP="$(find "$HOME/Library/Developer/Xcode/DerivedData" \
  -path "*/Build/Products/$CONFIG_DIR/Runner.app" -maxdepth 5 -type d \
  2>/dev/null | head -1)"
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
