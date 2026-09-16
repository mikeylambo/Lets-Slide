#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
source "$HERE/_godot.sh"
GODOT_BIN="$(resolve_godot)"

ARGS=(--export-courses)
if [[ "${1:-}" == "--force" ]]; then
  ARGS+=(--force-export-courses)
fi

"$GODOT_BIN" --headless --path "$ROOT" -- "${ARGS[@]}"
