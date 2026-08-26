#!/bin/bash
# Build ancre.app bundle from the SPM executable.
# Usage: Scripts/bundle.sh [debug|release]   (default: debug)
set -euo pipefail
cd "$(dirname "$0")/.."

# "universal" builds an arm64+x86_64 fat binary (used by the release CI).
CONF="${1:-debug}"
if [ "$CONF" = "universal" ]; then
    swift build -c release --arch arm64 --arch x86_64
    BUILT=".build/apple/Products/Release"
else
    swift build -c "$CONF"
    BUILT=".build/$CONF"
fi

BIN="$BUILT/ancre"
APP=".build/ancre.app"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp Scripts/Info.plist "$APP/Contents/Info.plist"
cp "$BIN" "$APP/Contents/MacOS/ancre"
# SPM resource bundles (default.toml etc.)
find ".build/$CONF" -maxdepth 1 -name '*.bundle' -exec cp -R {} "$APP/Contents/Resources/" \;

# Brand assets: app icon + menubar template image
BRAND="docs/brand/ancre-fixed-point-brand-kit"
cp "$BRAND/macos/ancre.icns" "$APP/Contents/Resources/"
cp "$BRAND"/menubar/AncreMenuTemplate*.png "$APP/Contents/Resources/" 

# Stable ad-hoc signature: identifier must stay constant or macOS forgets
# granted Accessibility/Input Monitoring permissions on each rebuild.
codesign --force --sign - --identifier com.ancre.wm "$APP"

echo "Built $APP"
