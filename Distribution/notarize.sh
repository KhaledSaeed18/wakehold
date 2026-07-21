#!/usr/bin/env bash
# Notarize and staple the packaged app. Store a notarytool keychain profile once:
#
#   xcrun notarytool store-credentials wakehold --apple-id you@example.com --team-id TEAMID
#   ./Distribution/notarize.sh
#
set -euo pipefail
cd "$(dirname "$0")/.."

ZIP="build/Wakehold.zip"
APP="build/Build/Products/Release/Wakehold.app"
PROFILE="${NOTARY_PROFILE:-wakehold}"

echo "==> Submitting to notarytool"
xcrun notarytool submit "$ZIP" --keychain-profile "$PROFILE" --wait

echo "==> Stapling the ticket"
xcrun stapler staple "$APP"
ditto -c -k --keepParent "$APP" "$ZIP"
echo "Notarized and stapled. $ZIP is ready to attach to a GitHub release."
