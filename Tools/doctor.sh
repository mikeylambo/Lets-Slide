#!/usr/bin/env bash
# Reports the environment this project expects.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/_godot.sh"
if GODOT_BIN="$(resolve_godot)"; then
  echo "godot binary : $GODOT_BIN"
  "$GODOT_BIN" --headless --version 2>/dev/null || true
else
  echo "godot binary : NOT FOUND"
fi
echo "expected     : Godot 4.7.x (GDScript, no .NET required)"
