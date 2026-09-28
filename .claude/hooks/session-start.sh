#!/bin/bash
# Claude Code on the web: install headless Godot so Tools/verify.sh, probes,
# the generator and the playtest-harness gate all run from any session
# (including mobile). Local machines keep their own Godot install.
set -euo pipefail

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

GODOT_VERSION="4.7.2-stable"
INSTALL_DIR="/opt/godot/${GODOT_VERSION}"
BIN="${INSTALL_DIR}/godot"
PROJECT="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"

if [ ! -x "$BIN" ]; then
  echo "Installing Godot ${GODOT_VERSION}..." >&2
  tmp="$(mktemp -d)"
  url="https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}/Godot_v${GODOT_VERSION}_linux.x86_64.zip"
  for attempt in 1 2 3 4; do
    if curl -fsSL --retry 2 -o "$tmp/godot.zip" "$url"; then break; fi
    [ "$attempt" = 4 ] && { echo "Godot download failed" >&2; exit 1; }
    sleep $((attempt * 2))
  done
  unzip -q -o "$tmp/godot.zip" -d "$tmp"
  mkdir -p "$INSTALL_DIR"
  mv "$tmp/Godot_v${GODOT_VERSION}_linux.x86_64" "$BIN"
  chmod +x "$BIN"
  rm -rf "$tmp"
fi

# Put it on PATH so Tools/_godot.sh resolves it without GODOT being set.
ln -sf "$BIN" /usr/local/bin/godot
echo "export GODOT=\"$BIN\"" >> "${CLAUDE_ENV_FILE:-/dev/null}"

# Warm the import cache (.godot/) so the first verify is fast. Parse errors
# are left for Tools/verify.sh to report; never block session start on them.
"$BIN" --headless --path "$PROJECT" --import >/dev/null 2>&1 || true

echo "Godot ready: $("$BIN" --version)" >&2
