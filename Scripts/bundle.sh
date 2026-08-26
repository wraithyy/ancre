#!/bin/bash
# Build ancre.app bundle from the SPM executable.
# Usage: Scripts/bundle.sh [debug|release]   (default: debug)
set -euo pipefail
cd "$(dirname "$0")/.."

CONF="${1:-debug}"
swift build -c "$CONF"

BIN=".build/$CONF/ancre"
APP=".build/ancre.app"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp Scripts/Info.plist "$APP/Contents/Info.plist"
cp "$BIN" "$APP/Contents/MacOS/ancre"
# SPM resource bundles (default.toml etc.)
find ".build/$CONF" -maxdepth 1 -name '*.bundle' -exec cp -R {} "$APP/Contents/Resources/" \;

# Stable ad-hoc signature: identifier must stay constant or macOS forgets
# granted Accessibility/Input Monitoring permissions on each rebuild.
codesign --force --sign - --identifier com.ancre.wm "$APP"

echo "Built $APP"
