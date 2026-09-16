#!/usr/bin/env bash
# Shared Godot resolver for local/headless tools.
resolve_godot() {
  if [[ -n "${GODOT:-}" ]]; then
    if [[ -x "$GODOT" ]] || command -v "$GODOT" >/dev/null 2>&1; then
      command -v "$GODOT" 2>/dev/null || printf '%s\n' "$GODOT"
      return 0
    fi
    printf 'GODOT is set but not executable/found: %s\n' "$GODOT" >&2
    return 1
  fi

  local name
  for name in godot godot4; do
    if command -v "$name" >/dev/null 2>&1; then
      command -v "$name"
      return 0
    fi
  done

  local candidate
  for candidate in \
    "/Applications/Godot.app/Contents/MacOS/Godot" \
    "$HOME/Applications/Godot.app/Contents/MacOS/Godot"; do
    if [[ -x "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  printf 'Godot not found. Set GODOT=/full/path/to/Godot (expected 4.7.x).\n' >&2
  return 1
}

# Native Windows Godot does not understand MSYS paths such as /d/project.
# Keep shell-side paths unchanged for find/test, and normalize only arguments
# passed to the engine.
godot_path() {
  local path="$1"
  if command -v cygpath >/dev/null 2>&1; then
    cygpath -w "$path"
  else
    printf '%s\n' "$path"
  fi
}
