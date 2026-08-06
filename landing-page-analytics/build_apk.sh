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

# Write release metadata next to the APK so the site can show version + date.
VERSION_LINE="$(grep '^version:' "$FLUTTER_DIR/pubspec.yaml" | awk '{print $2}')"
APP_VERSION="${VERSION_LINE%%+*}"          # 1.0.0
APP_BUILD="${VERSION_LINE##*+}"            # 1
BUILT_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"  # ISO-8601 UTC
VERSION_JSON="$(dirname "$DEST")/version.json"
cat > "$VERSION_JSON" <<JSON
{
  "version": "$APP_VERSION",
  "build": "$APP_BUILD",
  "builtAt": "$BUILT_AT"
}
JSON
echo "✓ Wrote $VERSION_JSON  (v$APP_VERSION+$APP_BUILD @ $BUILT_AT)"
