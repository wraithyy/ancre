#!/bin/bash
# Build ancre.app bundle from the SPM executable.
# Usage: Scripts/bundle.sh [debug|release|universal] [--install]
#   (default: debug; --install copies the bundle to /Applications)
set -euo pipefail
cd "$(dirname "$0")/.."

# "universal" builds arm64+x86_64 and lipos them (used by the release CI;
# `swift build --arch a --arch b` is broken on CI toolchains).
CONF="debug"
INSTALL=0
for arg in "$@"; do
    case "$arg" in
        --install) INSTALL=1 ;;
        *) CONF="$arg" ;;
    esac
done

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
# SPM resource bundles (default.toml etc.). Trailing slash: .build/debug is
# a symlink and find won't descend into it otherwise.
find "$BUILT/" -maxdepth 1 -name '*.bundle' -exec cp -R {} "$APP/Contents/Resources/" \;

# Brand assets: app icon + menubar template image
BRAND="docs/brand/ancre-fixed-point-brand-kit"
cp "$BRAND/macos/ancre.icns" "$APP/Contents/Resources/"
cp "$BRAND"/menubar/AncreMenuTemplate*.png "$APP/Contents/Resources/" 

# Stable ad-hoc signature: identifier must stay constant or macOS forgets
# granted Accessibility/Input Monitoring permissions on each rebuild.
codesign --force --sign - --identifier com.ancre.wm "$APP"

echo "Built $APP"

# Installing gives the permission grant one stable path to bind to: macOS ties
# Accessibility/Input Monitoring approval to the bundle's location, so granting
# it to a .build bundle breaks as soon as that path is rebuilt or cleaned.
if [ "$INSTALL" = "1" ]; then
    DEST="/Applications/ancre.app"
    pkill -x ancre 2>/dev/null || true
    rm -rf "$DEST"
    cp -R "$APP" "$DEST"
    echo "Installed $DEST"
fi
