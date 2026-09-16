#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
source "$HERE/_godot.sh"
GODOT_BIN="$(resolve_godot)"
REGION="${1:-0}"
COUNT="${2:-50}"
"$GODOT_BIN" --headless --path "$ROOT" -- --generate "--region=$REGION" "--count=$COUNT"
