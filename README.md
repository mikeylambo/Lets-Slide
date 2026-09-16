# LET'S SLIDE — Full GDD Build

Godot 4.7.x · GDScript · PC-first · mobile-capable

**Terrain is the moveset. There is no normal jump.** This archive is the full-system
implementation pass of the v1.2 GDD: the original SM64-reference movement lab and
vertical slice have been expanded into the complete campaign/mode/content architecture.

## Run

```bash
Tools/run.sh
Tools/lab.sh
Tools/verify.sh
Tools/verify-full.sh
```

The shell scripts auto-detect `godot`, `godot4`, and the standard macOS Godot.app paths.
Your local `Tools/verify.sh` remains the primary gate.

## Controls

| Action | Keyboard | Pad |
|---|---|---|
| Steer | A / D | Left stick X |
| Weight transfer / air lean | W / S | Left stick Y |
| Tuck | Shift | X / Square |
| Brake | Space | B / Circle |
| Retry | R | Y / Triangle |
| Pause | Esc | Start |
| Movement Lab | F1 (`fn`+F1 on many Macs) | — |
| Telemetry | F2 | — |
| Swap SLIDE / SM64 reference | F3 | — |
| Developer course inspector | F4 | — |

## Camera fix

The gameplay camera is now **rider-anchored**. Lookahead modifies aim/pitch only; it
never drags the camera pivot down-track, which was the reason the rider could disappear.
For normal +Z travel, the spring arm is rotated 180° so it sits physically behind the
rider and the Camera3D looks forward along the run. Course starts deliberately invert
that relationship: the camera begins ahead of the rider, looks back at them, then swivels
180° during the 2.4 s countdown into the chase position.

The tuned `Current Candidate` camera preset is loaded into the **actual** course camera.

## Implemented GDD systems

### Movement and feel
- Permanent Movement Lab with live motor/camera tuning and presets.
- SM64 reference motor at the original 30 Hz simulation domain.
- Production SLIDE motor at 120 Hz. Steering bends momentum rather than generating it.
- No normal jump; dev-only jump remains in the lab as a falsifiable design toggle.
- Ground weight transfer for crest release, compression timing and landing matching.
- Surface classes, landing quality, bonks, wall response, checkpoint momentum carry.

### Complete terrain grammar
All 24 GDD verbs share one data-driven builder and metadata table:

`straight drop bank bowl ramp gap wall funnel crest compression patch chicane ridge`
`transfer bank_to_wall corkscrew fullpipe shaft conveyor avalanche updraft hazard split tunnel`

Each verb has tier, intensity, speed effect, entry-speed requirements, recovery and
adjacency metadata. Authored and procedural courses use the same geometry/collision path.

### Campaign and progression
- Five regions × five authored courses = **25 courses**.
- Region Descents are longer synthesis courses.
- Medal gating; physics never changes with progression.
- Author / Gold / Silver / Bronze medals.
- Campaign Mastery Rank D → SS with time / physical momentum / score / mastery axes.
- Cosmetics are progression rewards only and never modify physics.
- PB ghost plus generated author-line ghost.

### Modes
- Campaign
- Time Trial — pure time
- Score Attack — Flow + score
- Survival — continuous authored courses, three lives
- Daily Descent — deterministic date seed, permanent First Sight + unlimited retries
- Endless — generated sections with rising prestige

### FLOW / presentation
- WARM → LIT → BURN → INVERT.
- Flow is independent from physical momentum.
- Pickup multipliers x1 / x2 / x3 / x5.
- Rider trail/emission escalation, chromatic separation and full-scene INVERT treatment.
- Region-aware Shelf architecture built procedurally around every course.

### Audio spine
`AudioDirector` is asset-free but functional now: surface/speed voice, wind pressure, Flow
tonality, region pitch identity and hard mistake ducking. It exposes the same hooks the
final original adaptive OST stems will use, so audio content can be replaced without
rewriting gameplay.

### Procedural generation / solo-dev content pipeline
- Machine-readable VerbLibrary.
- Five rhythm curves: steady climb, double peak, late spike, sawtooth, front-loaded.
- Rest-beat enforcement and running speed estimate.
- Deterministic Daily and generated Endless courses.
- Structural GenerationValidator.
- Real-physics CourseProbe for authored or generated seeds.
- HumanToleranceProbe with ~190 ms reaction delay and steering error.
- Developer Course Inspector (F4) for hot-editing verb kind/length/slope and rebuilding.
- 50-candidate generator batch tool.

Useful commands:

```bash
Tools/probe.sh course_01
Tools/human-probe.sh course_01
Tools/generate.sh 0 50
Tools/probe-generated.sh 100003 0 14
Tools/human-probe-generated.sh 100003 0
Tools/generate-probe.sh 0 50
Tools/verify-full.sh
```

### Persistence / records / boards
- Per-course best time, score, medal, Campaign rank, mastery and Flow.
- Daily First Sight and best result.
- Endless prestige.
- Local/offline leaderboard implementation behind `ShellBridge`; replace only that seam
  when a real backend/platform board is connected.
- User-facing leaderboard browser included.

### Mobile
- Touch steering field + explicit Tuck/Brake buttons.
- Optional accelerometer steering path.
- Mobile renderer is already the project default.

## What still requires content/service rather than more architecture

The gameplay architecture in the GDD is present. Two deliberately external pieces are not
faked:

1. **Online/global leaderboard backend.** The in-game and local board contract is complete
   behind `ShellBridge`; production credentials/service choice are still required.
2. **Final original OST masters.** The adaptive runtime and Flow/surface hooks exist, but
   the actual authored music stems are creative audio assets rather than code.

Split-screen and the public course editor remain post-v1 exactly as the GDD specifies.

## Verification philosophy

`Tools/verify.sh` performs import, headless unit tests, and a real project smoke test.
`Tools/verify-full.sh` follows that with safe-line physical probes for all 25 authored
courses. The generator has separate physical and human-tolerance probes.

This archive was authored in a container without a Godot executable, so I have not marked
new full-scope checks green here. Run the local gates before treating any newly generated
course or verb as playtested. Your previous base `Tools/verify.sh` already passed locally;
the full build is intended to preserve that same one-command iteration loop.


## v1.0 beat-grid authoring pipeline

Campaign geometry is authored at **174 BPM** in bars, not metres. `MotorParams.author_avg_speed` is the single scale authority; changing it rescales the mountain at build time while preserving musical form. `Tools/verify.sh` exports and round-trips the 25 `CourseData` resources into `content/courses/` before running unit and smoke gates.

Useful commands:

```bash
Tools/export-courses.sh
Tools/verify.sh
Tools/verify-full.sh
Tools/generate.sh 0 50
Tools/probe-generated.sh 100003 0 32
Tools/human-probe-generated.sh 100003 0
```

Region I is now authored as five distinct courses with signature moments. Regions II–V use distinct musical forms as bootstrap content and should be promoted through generate → probe → human-probe → F4 hand-tune before final release.
