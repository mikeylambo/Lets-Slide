# LET'S SLIDE audio drop-in

The runtime supports five optional 174 BPM stems per region. Export every stem from the exact same bar-1/beat-1 start point so they phase-align when the run begins.

Directory layout:

```text
content/audio/
  region_01/
    bed.ogg
    low.ogg
    mid.ogg
    high.ogg
    invert.ogg
  region_02/
  region_03/
  region_04/
  region_05/
```

Flow mapping:

- `bed.ogg` — always active
- `low.ogg` — WARM+
- `mid.ogg` — LIT+
- `high.ogg` — BURN+
- `invert.ogg` — INVERT only

Missing files are allowed. If a region has no music stems at all, `AudioDirector` keeps the procedural Flow tone as a fallback. Procedural surface and wind audio remain active even when real music stems are present.

Recommended export contract:

- 174 BPM
- same sample rate and exact start point for all five files
- no leading silence differences between stems
- seamless loop length shared by all stems
- OGG Vorbis

Godot should import long stems as streamed audio. For continuous looping, enable looping on the imported OGG resources or export a loop-safe arrangement long enough for the target course duration.
