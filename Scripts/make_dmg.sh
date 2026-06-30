#!/bin/bash
#
# Packages the built Lockleaf.app into a distributable macOS disk image (.dmg)
# with a drag-to-Applications layout — the conventional macOS "installer".
#
# Uses only the built-in `hdiutil` and `codesign` (no create-dmg / npm / brew),
# so it runs identically on a developer Mac and on a clean CI runner.
#
# Usage: ./Scripts/make_dmg.sh [version]
#   version  Optional. Defaults to the app's CFBundleShortVersionString.
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/build/Lockleaf.app"
VOL_NAME="Lockleaf"

if [ ! -d "$APP" ]; then
    echo "✗ $APP not found. Run ./Scripts/build_app.sh first." >&2
    exit 1
fi

# Resolve the version: explicit arg wins, else read it from the bundle.
VERSION="${1:-}"
if [ -z "$VERSION" ]; then
    VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist" 2>/dev/null || echo "1.0.0")"
fi

DMG="$ROOT/build/Lockleaf-$VERSION.dmg"
STAGING="$(mktemp -d)"
trap 'rm -rf "$STAGING"' EXIT

echo "▶︎ Staging disk image contents…"
# ditto preserves the app's code signature and symlinks.
ditto "$APP" "$STAGING/Lockleaf.app"
# The drag-to-install target.
ln -s /Applications "$STAGING/Applications"

echo "▶︎ Building compressed disk image…"
rm -f "$DMG"
hdiutil create \
    -volname "$VOL_NAME" \
    -srcfolder "$STAGING" \
    -fs HFS+ \
    -format UDZO \
    -imagekey zlib-level=9 \
    -ov \
    "$DMG" >/dev/null

echo "▶︎ Code signing the disk image (ad-hoc)…"
codesign --force --sign - "$DMG"

echo "▶︎ Verifying…"
hdiutil verify "$DMG" >/dev/null && echo "   image verified"
SHA="$(shasum -a 256 "$DMG" | awk '{print $1}')"

echo "✅ Built installer: $DMG"
echo "   version: $VERSION"
echo "   sha256:  $SHA"
