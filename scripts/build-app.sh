#!/usr/bin/env bash
# Builds build/Herdview.app from a release build and ad-hoc signs it.
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$(pwd)"
APP="$ROOT/build/Herdview.app"
CONFIG="${1:-release}"
ARCH="$(uname -m)"

# macOS decides which design an app gets from the SDK version stamped into its
# binary, not from the SDK on the build machine: an app declaring an SDK older
# than 26 is handed the pre-Tahoe look and Liquid Glass is withheld from its
# toolbar. SwiftPM stamps the deployment target as the SDK version too, so a
# package that deploys to macOS 13 ships a binary claiming SDK 13 and never
# gets the new appearance however new the machine building it is. Say the two
# separately: still runs on 13, but was built and checked against 26.
#
# It is on the packaging script rather than in Package.swift so that a plain
# `swift build` — the compile check — stays free of unsafe linker flags.
PLATFORM_VERSION=(-Xlinker -platform_version -Xlinker macos -Xlinker 13.0 -Xlinker 26.0)

echo "Building ($CONFIG, $ARCH)..."
swift build -c "$CONFIG" --arch "$ARCH" "${PLATFORM_VERSION[@]}"
BINDIR="$(swift build -c "$CONFIG" --arch "$ARCH" --show-bin-path)"

echo "Assembling $APP ..."
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BINDIR/herdview" "$APP/Contents/MacOS/herdview"
cp "$ROOT/scripts/AppInfo.plist" "$APP/Contents/Info.plist"
cp "$ROOT/scripts/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"

codesign --force --sign - "$APP" >/dev/null
echo "Done: $APP"
