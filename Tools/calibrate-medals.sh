#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
source "$HERE/_godot.sh"
GODOT_BIN="$(resolve_godot)"
MODE="${1:-region1}"

if [[ ! -f "$ROOT/content/courses/course_01.tres" ]]; then
  "$HERE/export-courses.sh"
fi

if [[ "$MODE" == "all" ]]; then START=1; END=25; else START=1; END=5; fi
CSV="$(mktemp -t lets-slide-medals.XXXXXX.csv)"
trap 'rm -f "$CSV"' EXIT

for n in $(seq "$START" "$END"); do
  id=$(printf 'course_%02d' "$n")
  echo "== calibrate $id =="
  set +e
  out=$("$HERE/probe.sh" "$id" 2>&1)
  status=$?
  set -e
  printf '%s\n' "$out"
  if [[ $status -ne 0 ]]; then
    echo "CALIBRATION FAIL: $id did not pass the physical probe" >&2
    exit $status
  fi
  time=$(printf '%s\n' "$out" | awk '/^[[:space:]]*time[[:space:]]*:/ {print $3; exit}')
  score=$(printf '%s\n' "$out" | awk '/^[[:space:]]*score[[:space:]]*:/ {print $3; exit}')
  if [[ -z "${time:-}" ]]; then
    echo "CALIBRATION FAIL: could not parse finish time for $id" >&2
    exit 95
  fi
  printf '%s,%s,%s\n' "$id" "$time" "${score:-0}" >> "$CSV"
done

"$GODOT_BIN" --headless --path "$ROOT" -- --apply-medals "--medal-file=$CSV"
echo "Measured medal times written for $MODE."
