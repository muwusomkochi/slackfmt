#!/bin/bash
# A7: a canary line through ten conversions and the throw case is found nowhere the app could have left it.
set -uo pipefail
cd "$(dirname "$0")/.."
CANARY="canary-$(uuidgen | tr -d - | tr A-Z a-z)"
ACCEPT=.build/release/slackfmt-accept
began=$(mktemp)
sleep 1
one=$("$ACCEPT" a7 "$CANARY"); echo "$one"
two=$("$ACCEPT" a7-throw "$CANARY"); echo "$two"
pkill -x Slackfmt; sleep 2
outputs=$(printf '%s\n%s\n' "$one" "$two" | awk '/^output /{print $2; print $3}')
found=0
errors=$(mktemp)
list=$(mktemp)
look() {
  if [ ! -e "$1" ]; then echo "ok   $1: not there"; return; fi
  # Only a file written since the canary existed can hold it. -type f: grep would wait for ever on a named pipe.
  find "$1" -type f -newer "$began" -print0 2>/dev/null > "$list"
  hits=$(xargs -0 -n 200 grep -laF -- "$CANARY" < "$list" 2>"$errors")
  if [ -n "$hits" ]; then echo "FAIL $1: $hits"; found=1; else echo "ok   $1: absent ($(tr -cd '\0' < "$list" | wc -c | tr -d ' ') files written since; $(wc -l < "$errors" | tr -d ' ') unreadable)"; fi
}
look "$HOME/Library/Containers/com.anoraq.slackfmt"
look "$TMPDIR"
look "$HOME/Library/Caches"
look "$HOME/Library/Application Support"
look "$HOME/Library/Logs"
for file in $outputs; do look "$file"; done
if log show --last 10m --predicate 'process == "Slackfmt"' --info --debug 2>/dev/null | grep -qF -- "$CANARY"; then echo "FAIL unified log"; found=1; else echo "ok   unified log: absent ($(log show --last 10m --predicate 'process == "Slackfmt"' --info --debug 2>/dev/null | wc -l | tr -d ' ') lines)"; fi
[ $found = 0 ] && echo "A7 PASSED" || echo "A7 FAILED"
