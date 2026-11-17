#!/bin/sh
# Bundle packages/core (via entry.ts) as an IIFE with the esbuild the lockfile pins (X1).
# Needs core's deps: npx --yes pnpm@10.30.1 install --frozen-lockfile --ignore-scripts --filter @slackfmt/core
# PLATFORM=neutral (default) takes each package's plain-JS "default" export and Turndown's
# DOM-free build (domino), since a JSContext is neither a browser nor Node. PLATFORM=browser
# takes the "browser" exports, which reach for document at load (X1's first run).
# Usage: [PLATFORM=browser] [OUTFILE=path] build.sh    default output probes/loop1/build/core.iife.js
set -eu
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." && pwd)"
ESBUILD="$(ls -d "$ROOT"/node_modules/.pnpm/esbuild@*/node_modules/esbuild/bin/esbuild | head -1)"
PLATFORM="${PLATFORM:-neutral}"
OUTFILE="${OUTFILE:-$HERE/../build/core.iife.js}"
# domino captures the timer globals at load and never calls them while parsing; these stubs
# throw, so a real call still surfaces.
SHIM='for (const n of ["setTimeout", "clearTimeout", "setInterval", "clearInterval"]) globalThis[n] ??= () => { throw new Error(n + " is not available in this JSContext"); };'
set -- --platform="$PLATFORM"
[ "$PLATFORM" = neutral ] && set -- "$@" --main-fields=module,main "--banner:js=$SHIM"
echo "esbuild $("$ESBUILD" --version), $*"
"$ESBUILD" "$HERE/entry.ts" --bundle --format=iife --target=safari17 --outfile="$OUTFILE" --log-level=warning "$@"
wc -c "$OUTFILE"
