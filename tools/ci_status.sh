#!/usr/bin/env bash
# The latest CI result in a few lines, instead of reading a whole Actions log.
#
#   tools/ci_status.sh            # latest run on the current branch
#   tools/ci_status.sh <run-id>   # a specific run
#   tools/ci_status.sh --watch    # wait for the latest run to finish first
#
# Prints each job's result, then for a failed job only the failing step's last
# lines (TAIL_LINES, default 30).
set -uo pipefail
REPO="AmericanGroupLLC/PilotEnRoute"
TAIL_LINES="${TAIL_LINES:-30}"
cd "$(dirname "$0")/.." || exit 2
branch="$(git branch --show-current)"

run="${1:-}"
if [ -z "$run" ] || [ "$run" = "--watch" ]; then
  id="$(gh run list -R "$REPO" -w ci.yml -b "$branch" -L 1 --json databaseId -q '.[0].databaseId')"
  [ -n "$id" ] || { echo "no CI run on $branch yet"; exit 1; }
  [ "$run" = "--watch" ] && gh run watch -R "$REPO" "$id" --exit-status >/dev/null 2>&1
  run="$id"
fi

gh run view -R "$REPO" "$run" --json status,conclusion,headSha,event,url,jobs -q '
  "run \(.url)\n\(.event) \(.headSha[0:7]) · \(.status) \(.conclusion // "")",
  (.jobs[] | "  \(.conclusion // .status | ascii_upcase)  \(.name)")'

failed="$(gh run view -R "$REPO" "$run" --json jobs -q '.jobs[] | select(.conclusion=="failure") | .databaseId')"
for j in $failed; do
  echo "── failed job $j (last $TAIL_LINES lines) ──"
  gh run view -R "$REPO" --job "$j" --log-failed 2>/dev/null \
    | sed -E 's/^[^\t]*\t[^\t]*\t[0-9TZ:.-]+ //' | tail -n "$TAIL_LINES"
done
