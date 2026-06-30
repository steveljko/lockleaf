#!/bin/bash
#
# Builds the Swift package and assembles a runnable, ad-hoc–signed macOS .app
# bundle — no Xcode project required. For App Store / notarized distribution,
# use the Xcode target described in README.md and sign with your Developer ID.
#
set -euo pipefail

CONFIG="${1:-release}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="Lockleaf"
EXECUTABLE="Lockleaf"
BUNDLE_ID="app.lockleaf.mac"

BUILD_DIR="$ROOT/.build/$CONFIG"
APP_DIR="$ROOT/build/$APP_NAME.app"
CONTENTS="$APP_DIR/Contents"

echo "▶︎ Building ($CONFIG)…"
swift build -c "$CONFIG" --product "$EXECUTABLE"

echo "▶︎ Assembling $APP_NAME.app…"
rm -rf "$APP_DIR"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources"

cp "$BUILD_DIR/$EXECUTABLE" "$CONTENTS/MacOS/$EXECUTABLE"
cp "$ROOT/Resources/Info.plist" "$CONTENTS/Info.plist"
[ -f "$ROOT/Resources/AppIcon.icns" ] && cp "$ROOT/Resources/AppIcon.icns" "$CONTENTS/Resources/"

# Bundle the SwiftPM resource bundles (if any) next to the executable.
for bundle in "$BUILD_DIR"/*.bundle; do
    [ -e "$bundle" ] && cp -R "$bundle" "$CONTENTS/Resources/"
done

# Ad-hoc signing cannot authorize restricted iCloud entitlements, and macOS will
# refuse to launch a binary that claims them without a provisioning profile. Use
# the iCloud-free dev entitlements here; the full set (Lockleaf.entitlements) is
# for the provisioned Xcode/Developer-ID build.
echo "▶︎ Code signing (ad-hoc) with dev entitlements (no iCloud)…"
codesign --force --deep \
    --sign - \
    --entitlements "$ROOT/Resources/Lockleaf-dev.entitlements" \
    --options runtime \
    "$APP_DIR"

echo "▶︎ Verifying signature…"
codesign --verify --verbose=2 "$APP_DIR"

echo "✅ Built: $APP_DIR"
echo "   Run with: open \"$APP_DIR\""
