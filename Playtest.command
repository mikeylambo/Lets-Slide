#!/usr/bin/env bash
# Double-click (macOS): build + launch the Let's Slide Playtest Harness on Course 01.
cd "$(dirname "$0")" && Tools/playtest.sh "$@"
[[ -f playtests/LATEST.md ]] && open playtests/LATEST.md
