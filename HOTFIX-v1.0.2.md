# LET'S SLIDE v1.0.2 — strict verification + Region I traversal hotfix

This revision responds to the first real `verify.sh` / `verify-full.sh` run on Godot 4.7.

## Fixed

- Unit tests now run through the real project (`-- --unit`) instead of `--script`, so the `Game` autoload exists while dependent scripts compile.
- `Tools/verify.sh` is now strict: a non-zero Godot exit **or** parser/runtime `ERROR:` / `SCRIPT ERROR:` output fails the gate. The old false-green state (`190 checks, 0 failures` despite engine errors) is no longer accepted.
- `TrackBuilder._add_effect()` no longer queries/sets a global transform before its `TrackEffect` is inside the SceneTree. This removes the headless updraft `!is_inside_tree()` error.
- Generator contract tests now execute in the same autoload-aware runtime as the game, fixing the cascade where `CourseGenerator` failed to compile because `Game` was unavailable.
- Region I Course 02 safe line was rebuilt to stay continuously downhill and avoid the 77% stall seen by the autopilot probe.
- Region I Course 03 was rebuilt without an unpaired `gap` verb. The prior generated teaching sentence could place a gap without a launch, causing repeated respawns near 170 m.
- Region I Course 04 was hand-authored as a broad, continuous tunnel lesson so its safe-line probe tests tunnel readability rather than generic grammar accidents.

## Run next

```bash
Tools/verify.sh
Tools/verify-full.sh
```

If `verify.sh` is green now, that green is meaningful. `verify-full.sh` should then expose only actual authored-course/probe failures.
