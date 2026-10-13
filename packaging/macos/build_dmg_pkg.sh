#!/usr/bin/env bash
# Packages the `flutter build macos --release` output into both a .dmg
# (drag-to-Applications disk image) and a .pkg (installer package). Run
# from the repo root on a Mac:
#   flutter build macos --release
#   bash packaging/macos/build_dmg_pkg.sh
#
# Produces unsigned/unnotarized artifacts — fine for sharing directly or
# for internal testing, but macOS Gatekeeper will warn on other people's
# Macs until you sign with your own Apple Developer ID and notarize via
# `xcrun notarytool`. That needs your own paid Apple Developer account and
# isn't something that can be pre-filled here.
set -euo pipefail

APP_NAME="Petal"
BUILD_DIR="build/macos/Build/Products/Release"
BUILD_APP="$BUILD_DIR/petal.app"
OUT_DIR="build/macos-installers"

if [ ! -d "$BUILD_APP" ]; then
  echo "error: $BUILD_APP not found — run 'flutter build macos --release' first." >&2
  exit 1
fi

if [ ! -x "$BUILD_APP/Contents/MacOS/petal" ]; then
  echo "error: the app executable is missing or not executable." >&2
  exit 1
fi

mkdir -p "$OUT_DIR"

# --- .dmg -------------------------------------------------------------
DMG_STAGING=$(mktemp -d)
trap 'rm -rf "$DMG_STAGING"' EXIT
# Flutter's actual bundle is petal.app. Give both installers the same,
# predictable display name, even on a case-sensitive APFS volume. ditto
# preserves bundle metadata and code signatures when copying macOS apps.
ditto "$BUILD_APP" "$DMG_STAGING/${APP_NAME}.app"
ln -s /Applications "$DMG_STAGING/Applications"
hdiutil create -volname "$APP_NAME" -srcfolder "$DMG_STAGING" -ov -format UDZO "$OUT_DIR/${APP_NAME}.dmg"
echo "Built $OUT_DIR/${APP_NAME}.dmg"

# --- .pkg -------------------------------------------------------------
pkgbuild --component "$DMG_STAGING/${APP_NAME}.app" \
  --install-location "/Applications" \
  --identifier "com.petal.player.pkg" \
  --version "1.0.0" \
  "$OUT_DIR/${APP_NAME}.pkg"
echo "Built $OUT_DIR/${APP_NAME}.pkg"
