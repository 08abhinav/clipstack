#!/usr/bin/env bash
# Builds ClipStack as a universal binary (Apple Silicon + Intel) into build/ClipStack.app
#
# Usage:
#   ./scripts/build-app.sh            # build the .app only
#   ./scripts/build-app.sh --dmg      # also create build/ClipStack.dmg (installer)
#   ./scripts/build-app.sh --zip      # also create build/ClipStack.zip
#   VERSION=1.2.0 ./scripts/build-app.sh --dmg   # set the app version
set -euo pipefail

cd "$(dirname "$0")/.."
APP="build/ClipStack.app"

swift build -c release --arch arm64 --arch x86_64
BIN="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)/ClipStack"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/ClipStack"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp -R Resources/*.lproj "$APP/Contents/Resources/"

if [[ -n "${VERSION:-}" ]]; then
  /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$APP/Contents/Info.plist"
fi

# Ad-hoc signature (no Apple Developer account). To ship without Gatekeeper
# warnings the app must be signed with a Developer ID and notarized.
codesign --force --deep --sign - "$APP"
echo "Built $APP"

for arg in "$@"; do
  case "$arg" in
    --zip)
      rm -f build/ClipStack.zip
      (cd build && ditto -c -k --keepParent ClipStack.app ClipStack.zip)
      echo "Created build/ClipStack.zip"
      ;;
    --dmg)
      STAGING="build/dmg"
      rm -rf "$STAGING" build/ClipStack.dmg
      mkdir -p "$STAGING"
      cp -R "$APP" "$STAGING/"
      ln -s /Applications "$STAGING/Applications"
      hdiutil create -volname "ClipStack" -srcfolder "$STAGING" -ov -format UDZO build/ClipStack.dmg >/dev/null
      rm -rf "$STAGING"
      echo "Created build/ClipStack.dmg"
      ;;
  esac
done
