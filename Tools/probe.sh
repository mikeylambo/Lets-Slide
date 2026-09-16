#!/usr/bin/env bash
# Autopilot descent of any authored course; defaults to course_01.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
source "$HERE/_godot.sh"
GODOT_BIN="$(resolve_godot)"
COURSE="${1:-course_01}"
"$GODOT_BIN" --headless --path "$ROOT" -- --probe "--course=$COURSE"
