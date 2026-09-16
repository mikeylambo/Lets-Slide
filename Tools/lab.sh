#!/usr/bin/env bash
# Launch straight into the Movement Lab (skips the menu).
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
source "$HERE/_godot.sh"
GODOT_BIN="$(resolve_godot)"
"$GODOT_BIN" --path "$ROOT" -- --lab
