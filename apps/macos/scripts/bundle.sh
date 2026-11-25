#!/bin/bash
# Bundles the fork's core as one IIFE for a JSContext, with the esbuild the lockfile pins (loop 1, X1).
# ENTRY overrides the entry file. platform=neutral takes each package's plain-JS export and Turndown's
# DOM-free build, since a JSContext is neither a browser nor Node.
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT="$(cd ../.. && pwd)"
ENTRY="${ENTRY:-js/entry.ts}"
ESBUILD="$(ls -d "$ROOT"/node_modules/.pnpm/esbuild@*/node_modules/esbuild/bin/esbuild | head -1)"
# domino captures the timer globals at load and never calls them while parsing, so a stub that throws still shows a real call.
SHIM='for (const n of ["setTimeout", "clearTimeout", "setInterval", "clearInterval"]) globalThis[n] ??= () => { throw new Error(n + " is not available in this JSContext"); };'
mkdir -p build
"$ESBUILD" "$ENTRY" --bundle --format=iife --target=safari17 --platform=neutral --main-fields=module,main \
  "--banner:js=$SHIM" --log-level=warning --outfile=build/slackfmt.js
echo "bundled build/slackfmt.js ($(wc -c < build/slackfmt.js | tr -d ' ') bytes, esbuild $("$ESBUILD" --version))"
