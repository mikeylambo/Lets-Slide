#!/usr/bin/env bash
# Release-candidate systems gate: unit/smoke + all authored physical probes +
# representative human-tolerance and generated-seed checks.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"$HERE/verify-full.sh" || exit $?
failed=0
for id in course_01 course_06 course_11 course_16 course_21 course_25; do
  echo "== human tolerance $id =="
  "$HERE/human-probe.sh" "$id" || failed=$((failed+1))
done
for region in 0 1 2 3 4; do
  seed=$((100003 + region * 10000))
  echo "== generated seed $seed / region $region =="
  "$HERE/probe-generated.sh" "$seed" "$region" 32 || failed=$((failed+1))
  "$HERE/human-probe-generated.sh" "$seed" "$region" || failed=$((failed+1))
done
echo "== release-gate failures: $failed =="
[[ "$failed" -eq 0 ]]
