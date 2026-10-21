#!/usr/bin/env bash
# Construit Balai.app (universel Apple Silicon + Intel) et une image disque .dmg.
# Usage : VERSION=0.1.0 ./scripts/build-app.sh
set -euo pipefail

APP_NAME="Balai"
VERSION="${VERSION:-0.1.0}"
BUILD_NUMBER="${BUILD_NUMBER:-$(date +%Y%m%d%H%M)}"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/build"
APP="$OUT/$APP_NAME.app"

cd "$ROOT"
echo "▸ Compilation (release, arm64 + x86_64)…"
swift build -c release --arch arm64 --arch x86_64
BIN_DIR="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)"

echo "▸ Assemblage de $APP_NAME.app…"
rm -rf "$OUT"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/$APP_NAME" "$APP/Contents/MacOS/$APP_NAME"
sed -e "s/__VERSION__/$VERSION/" -e "s/__BUILD__/$BUILD_NUMBER/" \
    "$ROOT/Resources/Info.plist" > "$APP/Contents/Info.plist"
if [ -f "$ROOT/Resources/AppIcon.icns" ]; then
    cp "$ROOT/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
    /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" "$APP/Contents/Info.plist"
fi

echo "▸ Signature ad hoc…"
codesign --force --deep --sign - "$APP"

echo "▸ Création du .dmg…"
STAGING="$OUT/dmg"
mkdir -p "$STAGING"
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"
# Nom fixe : le lien « releases/latest/download/Balai.dmg » et le cask Homebrew restent valables.
hdiutil create -volname "$APP_NAME" -srcfolder "$STAGING" -ov -format UDZO \
    "$OUT/$APP_NAME.dmg" >/dev/null
rm -rf "$STAGING"

echo "✓ $OUT/$APP_NAME.app"
echo "✓ $OUT/$APP_NAME.dmg ($VERSION)"
echo "  sha256 : $(shasum -a 256 "$OUT/$APP_NAME.dmg" | cut -d' ' -f1)"
