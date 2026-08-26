#!/bin/bash
# Build ancre.app bundle from the SPM executable.
# Usage: Scripts/bundle.sh [debug|release]   (default: debug)
set -euo pipefail
cd "$(dirname "$0")/.."

# "universal" builds arm64+x86_64 and lipos them (used by the release CI;
# `swift build --arch a --arch b` is broken on CI toolchains).
CONF="${1:-debug}"
if [ "$CONF" = "universal" ]; then
    swift build -c release --triple arm64-apple-macosx
    swift build -c release --triple x86_64-apple-macosx
    BUILT=".build/universal"
    mkdir -p "$BUILT"
    for bin in ancre ancrectl; do
        lipo -create ".build/arm64-apple-macosx/release/$bin" \
                     ".build/x86_64-apple-macosx/release/$bin" \
             -output "$BUILT/$bin"
    done
    find .build/arm64-apple-macosx/release -maxdepth 1 -name '*.bundle' -exec cp -R {} "$BUILT/" \;
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
find "$BUILT" -maxdepth 1 -name '*.bundle' -exec cp -R {} "$APP/Contents/Resources/" \;

# Brand assets: app icon + menubar template image
BRAND="docs/brand/ancre-fixed-point-brand-kit"
cp "$BRAND/macos/ancre.icns" "$APP/Contents/Resources/"
cp "$BRAND"/menubar/AncreMenuTemplate*.png "$APP/Contents/Resources/" 

# Stable ad-hoc signature: identifier must stay constant or macOS forgets
# granted Accessibility/Input Monitoring permissions on each rebuild.
codesign --force --sign - --identifier com.ancre.wm "$APP"

echo "Built $APP"
