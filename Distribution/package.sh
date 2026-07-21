#!/usr/bin/env bash
# Build, sign, and package Wakehold for distribution. Needs a Developer ID, so it is meant for the
# maintainer, not for unauthenticated CI. The wakehold CLI is embedded in the app bundle and a
# Homebrew cask symlinks it onto the PATH.
#
#   DEVELOPER_ID_APP="Developer ID Application: Your Name (TEAMID)" ./Distribution/package.sh
#
set -euo pipefail
cd "$(dirname "$0")/.."

: "${DEVELOPER_ID_APP:?set DEVELOPER_ID_APP to your Developer ID Application identity}"

BUILD_DIR="$(pwd)/build"
APP="$BUILD_DIR/Build/Products/Release/Wakehold.app"
ENTITLEMENTS="Distribution/Wakehold.entitlements"

echo "==> Building the app (Release, hardened runtime)"
xcodebuild -project Wakehold.xcodeproj -scheme Wakehold -configuration Release \
  -derivedDataPath "$BUILD_DIR" \
  ENABLE_HARDENED_RUNTIME=YES \
  CODE_SIGN_ENTITLEMENTS="$ENTITLEMENTS" \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY="$DEVELOPER_ID_APP" \
  clean build

echo "==> Building the wakehold CLI (Release)"
# The CLI goes in Contents/Helpers, not Contents/MacOS: the filesystem is case-insensitive, so a
# wakehold binary next to the app's own Wakehold executable would collide and overwrite it.
swift build --package-path WakeholdKit -c release --product wakehold
mkdir -p "$APP/Contents/Helpers"
cp "WakeholdKit/.build/release/wakehold" "$APP/Contents/Helpers/wakehold"

echo "==> Re-signing (embedded CLI first, then the app)"
codesign --force --options runtime --timestamp --sign "$DEVELOPER_ID_APP" \
  "$APP/Contents/Helpers/wakehold"
codesign --force --options runtime --timestamp --entitlements "$ENTITLEMENTS" \
  --sign "$DEVELOPER_ID_APP" "$APP"

echo "==> Zipping"
ditto -c -k --keepParent "$APP" "$BUILD_DIR/Wakehold.zip"
echo "Built $BUILD_DIR/Wakehold.zip. Notarize it with Distribution/notarize.sh."
