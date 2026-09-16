#!/usr/bin/env bash
# Exhaustive authored-content gate: quick verify plus all 25 safe-line probes.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"$HERE/verify.sh" || exit $?
failed=0
for n in $(seq -w 1 25); do
  id="course_$n"
  echo "== probe $id =="
  if ! "$HERE/probe.sh" "$id"; then
    failed=$((failed+1))
  fi
done
echo "== authored probe failures: $failed =="
[[ "$failed" -eq 0 ]]
