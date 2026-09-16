#!/usr/bin/env bash
# LET'S SLIDE — strict verify gate. Any Godot parser/runtime ERROR is a failure,
# even if a test runner accidentally exits 0.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
source "$HERE/_godot.sh"
GODOT_BIN="$(resolve_godot)"

run_gate() {
  local label="$1"; shift
  local log
  log="$(mktemp -t lets-slide-${label// /-}.XXXXXX.log)"
  echo "== $label =="
  set +e
  "$@" 2>&1 | tee "$log"
  local status=${PIPESTATUS[0]}
  set -e
  if [[ $status -ne 0 ]]; then
    echo "VERIFY FAIL: $label exited with status $status" >&2
    rm -f "$log"
    return $status
  fi
  if grep -Eq 'SCRIPT ERROR:|(^|[[:space:]])ERROR:|Parse Error|Compile Error' "$log"; then
    echo "VERIFY FAIL: $label emitted an engine/parser error" >&2
    grep -En 'SCRIPT ERROR:|(^|[[:space:]])ERROR:|Parse Error|Compile Error' "$log" >&2 || true
    rm -f "$log"
    return 97
  fi
  rm -f "$log"
}

run_gate "import" "$GODOT_BIN" --headless --path "$ROOT" --import
COURSE_COUNT="$(find "$ROOT/content/courses" -maxdepth 1 -name 'course_*.tres' 2>/dev/null | wc -l | tr -d ' ')"
if [[ "$COURSE_COUNT" != "25" ]]; then
  run_gate "course data export" "$GODOT_BIN" --headless --path "$ROOT" -- --export-courses
fi
if [[ "$(find "$ROOT/content/courses" -maxdepth 1 -name 'course_*.tres' | wc -l | tr -d ' ')" != "25" ]]; then
  echo "VERIFY FAIL: expected 25 serialized course files" >&2
  exit 96
fi
# Run unit tests through the real project so autoload singletons (Game) exist.
run_gate "unit tests" "$GODOT_BIN" --headless --path "$ROOT" -- --unit
run_gate "smoke test" "$GODOT_BIN" --headless --path "$ROOT" -- --smoke

echo "== all gates passed =="
