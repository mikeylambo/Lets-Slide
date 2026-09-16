#!/usr/bin/env bash
# Autopilot descent of any authored course; defaults to course_01.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
source "$HERE/_godot.sh"
GODOT_BIN="$(resolve_godot)"
GODOT_ROOT="$(godot_path "$ROOT")"
COURSE="${1:-course_01}"
# Preserve the production 120 Hz step while disabling wall-clock sync.
"$GODOT_BIN" --headless --fixed-fps 120 --path "$GODOT_ROOT" -- --probe "--course=$COURSE"
