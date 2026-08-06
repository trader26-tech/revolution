#!/usr/bin/env bash
# Build the Android release APK and drop it into the download folder so the
# site can serve it. Run from anywhere.
set -e

HERE="$(cd "$(dirname "$0")" && pwd)"
FLUTTER_DIR="$HERE/../frontend"
DEST="$HERE/frontend/downloads/revolution.apk"

echo "▶ Building release APK…"
( cd "$FLUTTER_DIR" && flutter build apk --release )

SRC="$FLUTTER_DIR/build/app/outputs/flutter-apk/app-release.apk"
if [ ! -f "$SRC" ]; then
  echo "✗ APK not found at $SRC"
  exit 1
fi

mkdir -p "$(dirname "$DEST")"
cp "$SRC" "$DEST"
echo "✓ APK copied to: $DEST"
echo "  Size: $(du -h "$DEST" | cut -f1)"
