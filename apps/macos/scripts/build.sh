#!/bin/bash
# Builds and signs build/Slackfmt.app by V12: arm64, macOS 14 or later, App Sandbox, hardened runtime with allow-jit.
# IDENTITY defaults to the SHA-1 of "Apple Development: hello@muwuso.com (F7GB63XQ29)", as his Linesman app's build does.
set -euo pipefail
cd "$(dirname "$0")/.."

IDENTITY="${IDENTITY:-26A223FD9ECAF4AEA148F8DE515DF42A944EC2CB}"
APP=build/Slackfmt.app

scripts/bundle.sh
swift build -c release --arch arm64 --product Slackfmt
BIN="$(swift build -c release --arch arm64 --show-bin-path)/Slackfmt"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Slackfmt"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp build/slackfmt.js "$APP/Contents/Resources/slackfmt.js"
codesign --force --sign "$IDENTITY" --options runtime --timestamp=none --entitlements Resources/Slackfmt.entitlements "$APP"
codesign --verify --strict --verbose=2 "$APP"
echo "built $(pwd)/$APP"
