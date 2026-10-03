#!/usr/bin/env bash
# Render a course's world-design shot list to PNGs.
#   Tools/world-shots.sh [course_id] [out_dir]
# Uses Xvfb when there is no display (CI / cloud), the window otherwise.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
source "$HERE/_godot.sh"
GODOT_BIN="$(resolve_godot)"
COURSE="${1:-course_01}"
OUT="${2:-$ROOT/build/world-shots/$COURSE}"
mkdir -p "$OUT"
CMD=("$GODOT_BIN" --path "$ROOT" --resolution 1600x900 -- "--world-shots=$OUT" "--course=$COURSE")
if [[ -z "${DISPLAY:-}" && "$(uname)" == "Linux" ]] && command -v xvfb-run >/dev/null; then
  xvfb-run -a -s "-screen 0 1600x900x24" "${CMD[0]}" --rendering-driver opengl3 "${CMD[@]:1}"
else
  "${CMD[@]}"
fi
echo "Shots written to $OUT"
