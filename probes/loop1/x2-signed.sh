#!/bin/sh
# X2's loop from a release executable signed ad hoc with the hardened runtime (V12), first
# without and then with com.apple.security.cs.allow-jit, which decides whether JavaScriptCore
# may use its JIT in the process.
set -eu
HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE/JSCProbe"
swift build -c release --product x2-time >/dev/null
BIN="$(swift build -c release --show-bin-path)/x2-time"
mkdir -p "$HERE/build"
for variant in no-jit allow-jit; do
  OUT="$HERE/build/x2-time-$variant"
  cp "$BIN" "$OUT"
  if [ "$variant" = allow-jit ]; then
    codesign -s - -f --options runtime --entitlements "$HERE/x2-allow-jit.entitlements" "$OUT" 2>/dev/null
  else
    codesign -s - -f --options runtime "$OUT" 2>/dev/null
  fi
  echo "== $variant: $(codesign -dv "$OUT" 2>&1 | grep -o 'flags=[^ ]*'); entitlements: $(codesign -d --entitlements - --xml "$OUT" 2>/dev/null | grep -o 'com.apple.security[a-z.-]*' || echo none)"
  "$OUT" "X2 $variant" || true
done
