#!/bin/bash
# Copies build/Slackfmt.app to /Applications, so the login item and the Services entry point at a copy that rebuilds don't
# remove, then registers it and refreshes the Services list. It doesn't launch the app.
set -euo pipefail
cd "$(dirname "$0")/.."

SRC=build/Slackfmt.app
DEST=/Applications/Slackfmt.app
LSREGISTER=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister

[ -d "$SRC" ] || { echo "no $SRC: run scripts/build.sh first"; exit 1; }
codesign --verify --strict "$SRC"

if pgrep -x Slackfmt >/dev/null; then
  echo "Slackfmt is running. Quit it, then run this again."
  exit 1
fi

if [ -e "$DEST" ]; then
  existing=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$DEST/Contents/Info.plist" 2>/dev/null || true)
  [ "$existing" = "com.anoraq.slackfmt" ] || { echo "$DEST exists and isn't Slackfmt ($existing); left alone"; exit 1; }
  rm -rf "$DEST"
fi

ditto "$SRC" "$DEST"
codesign --verify --strict "$DEST"
"$LSREGISTER" -u "$PWD/$SRC" >/dev/null 2>&1 || true
"$LSREGISTER" -f "$DEST"
/System/Library/CoreServices/pbs -update
echo "installed $DEST"
