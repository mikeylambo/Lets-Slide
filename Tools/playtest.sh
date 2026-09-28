#!/usr/bin/env bash
# One-click playtest: build (import + strict script check), then launch straight
# into the Playtest Harness. No editor required.
#
#   Tools/playtest.sh                         # Course 01, A = Current Candidate, B = Arcade Clean
#   Tools/playtest.sh course_03 --blind
#   Tools/playtest.sh course_01 --preset="Momentum Heavy" --b="High Grip"
#
# When you quit, the session handoff is at playtests/LATEST.md — paste it back.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
source "$HERE/_godot.sh"
GODOT_BIN="$(resolve_godot)"

COURSE="course_01"
if [[ $# -gt 0 && "$1" != --* ]]; then COURSE="$1"; shift; fi

echo "== build: importing project =="
LOG="$(mktemp -t lets-slide-playtest.XXXXXX.log)"
"$GODOT_BIN" --headless --path "$(godot_path "$ROOT")" --import >"$LOG" 2>&1 || true
if grep -Eq 'SCRIPT ERROR:|Parse Error|Compile Error' "$LOG"; then
  echo "BUILD FAIL — script errors:" >&2
  grep -En 'SCRIPT ERROR:|Parse Error|Compile Error' "$LOG" >&2 || true
  rm -f "$LOG"; exit 1
fi
rm -f "$LOG"

COMMIT="$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo local)"
git -C "$ROOT" diff --quiet 2>/dev/null || COMMIT="$COMMIT+dirty"
export LETS_SLIDE_COMMIT="$COMMIT"

echo "== launching harness on $COURSE =="
"$GODOT_BIN" --path "$(godot_path "$ROOT")" -- --harness --course="$COURSE" "$@"

if [[ -f "$ROOT/playtests/LATEST.md" ]]; then
  echo
  echo "== session handoff: $ROOT/playtests/LATEST.md =="
fi
