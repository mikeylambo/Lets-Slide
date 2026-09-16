#!/usr/bin/env bash
# Full generate -> physical probe gate for a region. Intended for overnight use.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REGION="${1:-0}"
COUNT="${2:-50}"
"$HERE/generate.sh" "$REGION" "$COUNT" || exit $?
accepted=0
rejected=0
for ((i=0; i<COUNT; i++)); do
  seed=$((100003 + REGION * 10000 + i * 7919))
  echo "== seed $seed =="
  if "$HERE/probe-generated.sh" "$seed" "$REGION" 32; then
    accepted=$((accepted+1))
  else
    rejected=$((rejected+1))
  fi
done
echo "== generated physical gate: $accepted accepted / $rejected rejected =="
[[ "$accepted" -gt 0 ]]
