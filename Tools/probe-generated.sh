#!/usr/bin/env bash
# Probe a deterministic generated seed through the real physics/collision path.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
source "$HERE/_godot.sh"
GODOT_BIN="$(resolve_godot)"
SEED="${1:-100003}"
REGION="${2:-0}"
BARS="${3:-32}"
"$GODOT_BIN" --headless --path "$ROOT" -- --probe "--seed=$SEED" "--region=$REGION" "--bars=$BARS"
