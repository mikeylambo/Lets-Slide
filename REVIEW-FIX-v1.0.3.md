# Review Fix v1.0.3

- Added a deliberate quarter-bar exception for `gap` so the beat-grid refactor does not inflate the original launch distance by ~58%.
- Added per-course bar-budget assertions and live `total_bars` synchronization in the F4 inspector.
- Added 2–3 recurring motif verbs per generated course with ~70% weighted reuse to create recognizable local vocabulary.
- Added measured medal calibration tooling. `Tools/calibrate-medals.sh` probes Region I and writes per-course Author/Gold/Silver/Bronze times into saved `.tres` resources; pass `all` to calibrate all 25.
- `verify.sh` no longer overwrites existing saved courses, preserving hand edits and measured medal times.
- Bootstrap/catalog medal times remain explicitly marked `medal_source = provisional` until calibrated.
