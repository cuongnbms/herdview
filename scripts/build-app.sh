#!/usr/bin/env bash
# Builds build/HerdPet.app from a release build and ad-hoc signs it.
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$(pwd)"
APP="$ROOT/build/HerdPet.app"
CONFIG="${1:-release}"
ARCH="$(uname -m)"

echo "Building ($CONFIG, $ARCH)..."
swift build -c "$CONFIG" --arch "$ARCH"
BINDIR="$(swift build -c "$CONFIG" --arch "$ARCH" --show-bin-path)"

echo "Assembling $APP ..."
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BINDIR/herdpet" "$APP/Contents/MacOS/herdpet"
cp "$ROOT/scripts/AppInfo.plist" "$APP/Contents/Info.plist"

codesign --force --sign - "$APP" >/dev/null
echo "Done: $APP"
