# LET'S SLIDE — Beat Grid 1.0 Candidate

Implemented from the 174 BPM authoring brief:

- Tempo authority at 174 BPM; bars ↔ metres conversion.
- `MotorParams.author_avg_speed` as the single geometry scale authority.
- All default verbs authored on a half-bar grid.
- TrackBuilder converts bars to metres once and emits `beat_map`.
- CourseData spec/tension are serializable; total bars/form/signature/BPM exported.
- 25 course resources export to `content/courses/*.tres`; runtime loads data files first.
- Five named musical course forms replace the one nine-beat campaign skeleton.
- Region I has five distinct authored specs and written signature moments.
- Generator works in bars and forms; Daily/Endless inherit the beat grid.
- F4 inspector edits bars directly.
- Strict verify now includes course export/round-trip presence gate.

## Local release gate

This container has no Godot executable. On the project Mac, run:

1. `Tools/verify.sh`
2. `Tools/verify-full.sh`
3. `Tools/generate.sh 0 50`
4. Probe/human-probe surviving Region I candidates if you want to replace any of the five authored Threshold specs.
5. Play Region I three times through and set measured medal times from the clean probe outputs.

The code intentionally does **not** claim final measured Region I medal calibration until those physical Godot probes run.
