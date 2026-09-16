# LET'S SLIDE — 1.0 Candidate Change Log

## Content architecture
- Replaced meter-authored campaign content with a 174 BPM bar grid.
- Added `Tempo.gd` and `author_avg_speed` content scaling.
- Added serializable course resources and data-first runtime loading.
- Added `Tools/export-courses.sh`; strict verify exports 25 `.tres` resources.
- Added five musical course forms and removed the repeated nine-beat skeleton.
- Rebuilt all bootstrap campaign specs around distinct forms.
- Authored Region I as five distinct Threshold courses with signature moments.

## Build/runtime
- TrackBuilder converts bars to metres once and emits a beat map.
- Daily and Endless generation now use bar budgets and course forms.
- F4 inspector edits half-bar duration directly.
- Pickup spacing follows the beat grid instead of fixed metres.
- Added verification checks for 174 BPM, bar serialization, five forms, and
  geometry rescaling at different author speeds.

## Remaining release gates (must be run in Godot)
1. `Tools/verify.sh`
2. `Tools/verify-full.sh`
3. Three human playthroughs of Region I.
4. Replace Region I bootstrap medal values with measured clean probe times.
5. Optional: promote Regions II–V from bootstrap-form content through the same
   authoring pipeline before public 1.0 if their playtests do not hold up.
