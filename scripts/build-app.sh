#!/usr/bin/env bash
# Builds build/Herdview.app from a release build and ad-hoc signs it.
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$(pwd)"
APP="$ROOT/build/Herdview.app"
CONFIG="${1:-release}"
ARCH="$(uname -m)"

echo "Building ($CONFIG, $ARCH)..."
swift build -c "$CONFIG" --arch "$ARCH"
BINDIR="$(swift build -c "$CONFIG" --arch "$ARCH" --show-bin-path)"

echo "Assembling $APP ..."
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BINDIR/herdview" "$APP/Contents/MacOS/herdview"
cp "$ROOT/scripts/AppInfo.plist" "$APP/Contents/Info.plist"
cp "$ROOT/scripts/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"

codesign --force --sign - "$APP" >/dev/null
echo "Done: $APP"
