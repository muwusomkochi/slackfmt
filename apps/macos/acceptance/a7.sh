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
look() {
  if [ ! -e "$1" ]; then echo "ok   $1: not there"; return; fi
  if hits=$(grep -rlaF -- "$CANARY" "$1" 2>/tmp/a7-errors); then echo "FAIL $1: $hits"; found=1; else echo "ok   $1: absent ($(find "$1" -type f 2>/dev/null | wc -l | tr -d ' ') files; $(wc -l < /tmp/a7-errors | tr -d ' ') unreadable)"; fi
}
look "$HOME/Library/Containers/com.anoraq.slackfmt"
look "$TMPDIR"
look "$HOME/Library/Caches"
look "$HOME/Library/Application Support"
look "$HOME/Library/Logs"
for file in $outputs; do look "$file"; done
if log show --last 10m --predicate 'process == "Slackfmt"' --info --debug 2>/dev/null | grep -qF -- "$CANARY"; then echo "FAIL unified log"; found=1; else echo "ok   unified log: absent ($(log show --last 10m --predicate 'process == "Slackfmt"' --info --debug 2>/dev/null | wc -l | tr -d ' ') lines)"; fi
[ $found = 0 ] && echo "A7 PASSED" || echo "A7 FAILED"
