#!/usr/bin/env bash
# Build the "Pocket" web build: a no-threads WebGL export packaged for hosts
# that cap files at 15 MB and serve only web media types (e.g. a claude.ai
# artifact). The engine ships gzipped as engine.gz.wasm; Tools/web/pocket.html
# inflates it in the browser and maps Godot's requests onto the renamed files.
#
#   Tools/web-pocket.sh [out_dir]      # default: build/pocket
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
source "$HERE/_godot.sh"
GODOT_BIN="$(resolve_godot)"
OUT="${1:-$ROOT/build/pocket}"

VERSION="$("$GODOT_BIN" --version | sed -E 's/^([0-9]+\.[0-9]+(\.[0-9]+)?\.[a-z]+).*/\1/')"
TPL_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/godot/export_templates/$VERSION"
if [[ ! -f "$TPL_DIR/web_nothreads_release.zip" ]]; then
  TAG="${VERSION%.*}-${VERSION##*.}"
  echo "== fetching web export template for $VERSION (one-time, ~1.3 GB download) =="
  tmp="$(mktemp -d)"
  curl -fsSL -o "$tmp/t.tpz" "https://github.com/godotengine/godot/releases/download/$TAG/Godot_v${TAG}_export_templates.tpz"
  mkdir -p "$TPL_DIR"
  unzip -q -o -j "$tmp/t.tpz" templates/web_nothreads_release.zip templates/version.txt -d "$TPL_DIR"
  rm -rf "$tmp"
fi

RAW="$(mktemp -d)"
"$GODOT_BIN" --headless --path "$ROOT" --export-release "Web" "$RAW/index.html" >/dev/null
mkdir -p "$OUT"
cp "$RAW/index.js" "$RAW/index.audio.worklet.js" "$RAW/index.audio.position.worklet.js" "$OUT/"
cp "$RAW/index.pck" "$OUT/game.pck.wasm"
gzip -9 -c "$RAW/index.wasm" > "$OUT/engine.gz.wasm"
WASM=$(stat -c%s "$RAW/index.wasm" 2>/dev/null || stat -f%z "$RAW/index.wasm")
GZ=$(stat -c%s "$OUT/engine.gz.wasm" 2>/dev/null || stat -f%z "$OUT/engine.gz.wasm")
PCK=$(stat -c%s "$RAW/index.pck" 2>/dev/null || stat -f%z "$RAW/index.pck")
sed -e "s/const WASM_BYTES = [0-9]*;/const WASM_BYTES = $WASM;/" \
    -e "s/const GZ_BYTES = [0-9]*;/const GZ_BYTES = $GZ;/" \
    -e "s/'index.pck': [0-9]*/'index.pck': $PCK/" "$HERE/web/pocket.html" > "$OUT/index.html"
rm -rf "$RAW"
echo "== pocket build ready: $OUT (engine $((GZ/1048576)) MB gzipped, data $((PCK/1024)) KB) =="
