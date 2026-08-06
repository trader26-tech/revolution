#!/usr/bin/env bash
#
# Build a shareable release APK of the Revolution app.
#
# Run this on a machine that has the Android SDK (e.g. the M4 mini that runs the
# emulator). It builds against the LIVE Railway backend and prints the exact
# path of the .apk to upload to Google Drive.
#
#   cd frontend && ./build-apk.sh
#
set -euo pipefail

API="https://revolution-backend-production.up.railway.app"

# Ensure Flutter can find the Android SDK; hint common locations if not.
if ! flutter doctor 2>/dev/null | grep -q "Android toolchain"; then
  echo "⚠️  Flutter can't find the Android SDK on this machine."
  echo "   If it's installed, set it once:  flutter config --android-sdk <path>"
  echo "   (On the mini it's usually ~/Library/Android/sdk)"
fi

echo "→ Fetching packages…"
flutter pub get

echo "→ Building release APK (points at $API)…"
flutter build apk --release --dart-define=API_BASE_URL="$API"

APK="build/app/outputs/flutter-apk/app-release.apk"
if [[ -f "$APK" ]]; then
  SIZE=$(du -h "$APK" | cut -f1)
  echo
  echo "✅ APK ready ($SIZE):"
  echo "   $(pwd)/$APK"
  echo
  echo "Next: upload that file to Google Drive and share the link."
else
  echo "❌ Build finished but the APK wasn't found at $APK"
  exit 1
fi
