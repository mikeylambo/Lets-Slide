#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
source "$HERE/_godot.sh"
GODOT_BIN="$(resolve_godot)"
SEED="${1:-100003}"
REGION="${2:-0}"
"$GODOT_BIN" --headless --path "$ROOT" -- --human-probe "--seed=$SEED" "--region=$REGION"
