#!/bin/sh
# X6: `x6.sh build` builds and signs the probe app (ad hoc, App Sandbox, hardened runtime);
# `x6.sh install` also copies it to ~/Applications, registers and opens it once, runs
# `pbs -update` and reads pbs's service list back; `x6.sh uninstall` undoes all of it.
set -eu
HERE="$(cd "$(dirname "$0")" && pwd)"
NAME=SlackfmtX6Probe
APP="$HERE/../build/$NAME.app"
DEST="$HOME/Applications/$NAME.app"
LSREGISTER=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
PBS=/System/Library/CoreServices/pbs

build() {
    rm -rf "$APP"
    mkdir -p "$APP/Contents/MacOS"
    cp "$HERE/Info.plist" "$APP/Contents/Info.plist"
    swiftc -O -target arm64-apple-macos14.0 "$HERE/main.swift" -o "$APP/Contents/MacOS/$NAME"
    codesign --force --sign - --options runtime --entitlements "$HERE/x6.entitlements" "$APP"
    codesign -dv "$APP" 2>&1 | grep -E "^(Identifier|Format|CodeDirectory|Signature)"
    codesign -d --entitlements - --xml "$APP" 2>/dev/null | plutil -convert json -o - - 2>/dev/null; echo
}

case "${1:-build}" in
build) build ;;
install)
    build
    mkdir -p "$HOME/Applications"
    rm -rf "$DEST"
    ditto "$APP" "$DEST"
    "$LSREGISTER" -f "$DEST"
    open -g "$DEST"
    "$PBS" -update
    echo "installed $DEST; pbs -update exit $?"
    "$PBS" -dump 2>&1 | grep -n -E "Copy for Slack|$NAME|x6probe" || echo "pbs -dump: no line names the probe"
    ;;
uninstall)
    pkill -x "$NAME" || true
    [ -d "$DEST" ] && "$LSREGISTER" -u "$DEST" || true
    rm -rf "$DEST"
    "$PBS" -update
    echo "uninstalled; pbs -update exit $?"
    "$PBS" -dump 2>&1 | grep -c -E "Copy for Slack|$NAME|x6probe" || true
    ;;
*) echo "usage: x6.sh build|install|uninstall" >&2; exit 64 ;;
esac
