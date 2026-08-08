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
# Usage:  ./scripts/run-ios.sh
# Prereqs (one-time): CocoaPods on PATH (see below), signing team set in Xcode.

set -euo pipefail

# CocoaPods lives in the user gem dir (installed against system Ruby 2.6 with
# pinned deps). Add it to PATH so any pod step works.
export PATH="$HOME/.gem/ruby/2.6.0/bin:$PATH"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

DEVICE="${1:-$(flutter devices --machine 2>/dev/null \
  | python3 -c 'import sys,json;      \
      d=json.load(sys.stdin);         \
      ios=[x for x in d if x.get("targetPlatform","").startswith("ios") and not x.get("emulator")]; \
      print(ios[0]["id"] if ios else "")')}"

if [ -z "$DEVICE" ]; then
  echo "No iPhone found. Connect it (USB + unlock + Trust) and retry." >&2
  exit 1
fi
echo "▶ Target iPhone: $DEVICE"

BUNDLE_ID="com.revolution.revolution.dev"

echo "▶ flutter pub get"
flutter pub get >/dev/null

echo "▶ Building + signing (xcodebuild, allows provisioning updates)…"
xcodebuild \
  -workspace ios/Runner.xcworkspace \
  -scheme Runner \
  -configuration Debug \
  -destination "id=$DEVICE" \
  -allowProvisioningUpdates \
  build 2>&1 | grep -E "\*\* BUILD|error:" | grep -v "export " || true

APP="$HOME/Library/Developer/Xcode/DerivedData/Runner-aflglrzrbjcjvfetgvdnlfkxfexl/Build/Products/Debug-iphoneos/Runner.app"
# Fall back to a search if DerivedData path name differs.
if [ ! -d "$APP" ]; then
  APP="$(find "$HOME/Library/Developer/Xcode/DerivedData" \
    -path "*/Build/Products/Debug-iphoneos/Runner.app" -maxdepth 5 -type d \
    2>/dev/null | head -1)"
fi
echo "▶ App: $APP"

echo "▶ Installing to iPhone…"
xcrun devicectl device install app --device "$DEVICE" "$APP"

echo "▶ Launching…"
xcrun devicectl device process launch --device "$DEVICE" "$BUNDLE_ID"

echo "✓ Revolution is running on the iPhone."
echo "  (Debug build — to hot-reload, run: flutter attach -d $DEVICE)"
