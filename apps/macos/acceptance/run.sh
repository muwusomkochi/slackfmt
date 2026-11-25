#!/bin/bash
# Runs acceptance rows and keeps each one's output: acceptance/run.sh "a1 A1-A2" "a4 A4" "a15 A15" ...
# Each argument is the harness's command and the result file's name.
set -uo pipefail
cd "$(dirname "$0")/.."
for pair in "$@"; do
  name="${pair##* }"
  .build/release/slackfmt-accept ${pair% *} 2>&1 | tee "acceptance/results/$name.txt" | grep -E "^FAIL|^[AE][0-9].* (PASSED|FAILED)|note state|screenshot|isn't on screen|using the Mac|launch" | cut -c1-230
done
