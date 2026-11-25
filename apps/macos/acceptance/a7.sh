#!/bin/bash
# A7: a canary line through ten conversions and the throw case is found nowhere the app could have left it.
set -uo pipefail
cd "$(dirname "$0")/.."
CANARY="canary-$(uuidgen | tr -d - | tr A-Z a-z)"
ACCEPT=.build/release/slackfmt-accept
one=$("$ACCEPT" a7 "$CANARY"); echo "$one"
two=$("$ACCEPT" a7-throw "$CANARY"); echo "$two"
pkill -x Slackfmt; sleep 2
outputs=$(printf '%s\n%s\n' "$one" "$two" | awk '/^output /{print $2; print $3}')
found=0
errors=$(mktemp)
look() {
  if [ ! -e "$1" ]; then echo "ok   $1: not there"; return; fi
  # -type f: grep -r would wait for ever on a named pipe.
  hits=$(find "$1" -type f -print0 2>/dev/null | xargs -0 -n 500 -P 6 grep -laF -- "$CANARY" 2>"$errors")
  count=$(find "$1" -type f 2>/dev/null | wc -l | tr -d ' ')
  if [ -n "$hits" ]; then echo "FAIL $1: $hits"; found=1; else echo "ok   $1: absent ($count files; $(wc -l < "$errors" | tr -d ' ') unreadable)"; fi
}
look "$HOME/Library/Containers/com.anoraq.slackfmt"
look "$TMPDIR"
look "$HOME/Library/Caches"
look "$HOME/Library/Application Support"
look "$HOME/Library/Logs"
for file in $outputs; do look "$file"; done
if log show --last 10m --predicate 'process == "Slackfmt"' --info --debug 2>/dev/null | grep -qF -- "$CANARY"; then echo "FAIL unified log"; found=1; else echo "ok   unified log: absent ($(log show --last 10m --predicate 'process == "Slackfmt"' --info --debug 2>/dev/null | wc -l | tr -d ' ') lines)"; fi
[ $found = 0 ] && echo "A7 PASSED" || echo "A7 FAILED"
