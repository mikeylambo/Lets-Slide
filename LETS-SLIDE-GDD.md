# LET'S SLIDE — Game Design Document

*Working title, placeholder. Final name pending.*

**Version 1.3 — full-GDD implementation pass**
Godot 4.7 · GDScript · PC-first, mobile-capable

---

## 1. Premise

You descend. You cannot jump. Everything you can do is done by reading the
ground and deciding where to put your momentum.

A racing game gives you a track and asks you to drive it. This gives you a
mountain and asks you to *find the line*. Speed is not granted by a throttle —
it is inherited from gravity, spent on every turn, and protected by skill.

The **fall line** is the skiing term for the steepest path down a slope. Reading
it, committing to it, and knowing when to leave it is the entire game.

## 2. Pillars

1. **Terrain is the moveset.** Every capability the player has comes from a
   piece of geometry. New verbs are new abilities.
2. **Steering bends momentum, it never creates it.** Inherited from SM64's slide
   code and preserved deliberately. Every turn costs speed; banking gives it
   back. This is what makes line choice a real decision rather than a
   preference.
3. **Low floor, absurd ceiling.** A beginner sees left, right, don't fall. An
   expert sees line choice → banking → weight transfer → speed preservation →
   launch trajectory → aerial correction → landing angle → shortcut → recovery →
   route chaining.
4. **Mastery must be legible.** The community signal from the SM64 slide-hack
   scene is not "make it brutal" — it is "show me exactly what I did wrong and
   exactly what the next tier costs." Every failure is readable and every target
   is a number on screen.
5. **Failure is cheap, retry is instant.** Under one second, always. The whole
   design bet is that a 70-second course gets run two hundred times.

## 3. The frame

**Trackmania.** Short authored courses, four medal tiers, ghosts, per-course
leaderboards, no ability gating. Chosen over the alternatives for concrete
reasons:

- **SSX 3** runs its progression on a trick economy and a character/board shop.
  Both fight the no-jump stance — a trick button is exactly the "I don't like
  this terrain, I'll do something else" escape hatch we removed on purpose.
- **Descenders** generates its content procedurally, which undermines memorised,
  optimised lines. Route mastery and roguelite variance pull in opposite
  directions *within a single mode*. Separated into their own modes, they
  reinforce each other (§8).

**What the frame requires, and what already exists in the build:**

| Frame element | Status |
|---|---|
| Course → run → results → retry loop | built |
| Author / Gold / Silver / Bronze medals | built |
| Personal-best ghost record & playback | built |
| Per-course records, ranks, collectibles | built |
| Campaign structure, blocks, gating | to build |
| Leaderboards (backend) | seam built (`ShellBridge`), backend to build |
| Course editor | v2 |

---

## 4. What "good play" means

> Carry as much momentum as possible through the most demanding readable line,
> with intentional control rather than luck.

Four skills, rewarded in this order:

**Line reading → speed preservation → execution → recovery**

And, later in a player's life: **route discovery → optimisation → consistency**.

The **Campaign Mastery Rank** grades four axes. Momentum is weighted second only
to time precisely so that a sloppy fast run scores below a clean fast run.

| Axis | Weight | Measures |
|---|---|---|
| Time | 42% | Against author time, floored at 150% of bronze |
| Momentum | 26% | Physical speed retention and bonk efficiency |
| Score | 22% | Pickups and Flow multiplier against par |
| Mastery | 10% | Mastery collectibles found |

Ranks: **D · C · B · A · S · SS**

That composite grade belongs to Campaign and the general results screen; it is
**not** the competitive metric for every mode. Mode leaderboards stay pure:

- **Time Trial:** time only. A world-record line is never downgraded for ignoring
  pickups or Flow.
- **Score Attack:** score + Flow. Time is informational only.
- **Daily / Endless:** each board declares one primary metric; mixed-mode grades
  remain personal mastery feedback, not leaderboard ordering.

### 4.1 Weight transfer — receiving terrain, never creating energy

The no-jump stance does not mean the rider is passive. Stick Y controls body
position relative to the forces the terrain is already creating:

- **crest:** release cleanly or stay loaded into the surface
- **compression:** absorb/load the dip and improve the exit
- **launch:** bias trajectory without adding a free impulse
- **landing:** match the receiving slope to preserve momentum

Weight transfer must never create net speed on flat terrain and must never become
a bunny-hop surrogate. The skill is timing how the rider **receives and releases
existing forces**. Terrain remains the moveset; body timing determines how well
the player uses it.

---

## 5. FLOW — the style axis

There is no trick button, so style has to come from *how* the line is taken, not
from a separate input layer. Flow is that system, and it costs the player no new
controls.

**Flow builds** while:
- grounded and holding above 80% of your rolling peak speed
- airborne with the trajectory tracking toward a landable surface
- riding a wall, bowl wall, or bank above its midline
- passing within grazing distance of geometry without contact

**Flow breaks** on:
- a bonk
- a landing below 40% quality
- dropping under 55% of the segment's target speed
- any respawn

**Tiers:** `WARM → LIT → BURN → INVERT`

Each tier multiplies pickup value (×1 / ×2 / ×3 / ×5). **Flow does not feed the
Momentum axis.** Momentum asks how efficiently physical speed was preserved;
Flow asks how long the player sustained clean, dangerous, stylish play. They
correlate, but they are intentionally separate so a screaming-fast ugly run and
a slightly slower immaculate Flow run remain meaningfully different performances.

Flow is the score-attack spine and the reason a player takes the harder line when
the safe line is faster on paper.

Flow is also the visual and audio backbone (§11, §12). It is the single system
that makes momentum *visible*, which is the whole problem with momentum games:
speed is felt but rarely legible.

---

## 6. Verb grammar

Courses are authored as verb lists, never modelled. The grammar is the content
pipeline — a new course is a data change, and a new verb is available to every
course ever written, authored or generated.

### Foundation verbs (8) — implemented

| Verb | Reads as | Teaches |
|---|---|---|
| `straight` | Neutral slope | Baseline acceleration, surface feel |
| `drop` | Steep pitch | Gravity, commitment |
| `bank` | Banked turn | Carving, the bank-assist trade |
| `bowl` | Concave cross-section | Free carving, recovery, line freedom |
| `ramp` | Kicker lip | Deliberate launch |
| `gap` | Void | Airtime, landing |
| `wall` | Raised sides | Wall riding, transfers |
| `funnel` | Narrowing width | Precision under pressure |

### Expansion verbs (16) — implemented, pending playtest validation

| Verb | Reads as | Teaches | Tier |
|---|---|---|---|
| `crest` | Convex rise | **Terrain launches you with no kicker** — the purest expression of the pillar | 1 |
| `compression` | Dip that loads then releases | Weight transfer, speed gain from geometry | 2 |
| `patch` | Inline surface change | Reading a surface before you're on it | 1 |
| `chicane` | Rapid alternating banks | Rhythm, countersteer | 2 |
| `ridge` | Narrow spine, fall either side | Nerve, precision at speed | 3 |
| `transfer` | Twin walls, cross between | Wall-to-wall traversal | 3 |
| `bank_to_wall` | Bank rolling past vertical | Commitment, the bank/wall boundary | 3 |
| `corkscrew` | Bank rotating past 90° | Full rotation, orientation under speed | 4 |
| `fullpipe` | Closed tube | Total line freedom, orientation loss | 4 |
| `shaft` | Vertical drop-through | Falling as traversal | 3 |
| `conveyor` | Moving surface | External momentum | 2 |
| `avalanche` | Flowing surface, downhill drift | Momentum you didn't earn | 3 |
| `updraft` | Air-affecting volume | Aerial line extension | 3 |
| `hazard` | Static or timed obstacle | Route commitment under threat | 2 |
| `split` | Formalised fork/rejoin | Route decision | 1 |
| `tunnel` | Enclosure | Camera compression, speed perception | 1 |

**24 verbs total.** Tier 1 verbs are safe anywhere. Tier 4 verbs appear once per
course at most and only in the final two regions.

### Verb metadata

Every verb carries machine-readable properties, because both the human authoring
rules below and the generator in §7 read from the same table.

| Property | Purpose |
|---|---|
| `tier` | 1–4 difficulty band |
| `intensity` | 0–1 contribution to the tension curve |
| `speed_effect` | Builds, holds, or spends momentum |
| `requires_entry_speed` | Minimum m/s for the verb to be clearable |
| `recovery` | Whether the verb can serve as a rest beat |
| `pairs_well_with` / `reads_poorly_after` | Adjacency rules |

### Authoring rules

- A course introduces at most **one new verb**, and always in its safest form
  first.
- A verb appears **three times** in the course that introduces it: isolated,
  combined, then under pressure.
- Every course carries a **safe line, a fast line, a score line, and one mastery
  route**. The mastery route must be unreachable without speed protected at
  least two sections earlier.
- Re-run the autopilot probe after any geometry change; medal times are derived
  from it, never guessed.

---

## 7. Procedural generation

Procedural courses are built from the same verb grammar, the same builder and the
same collision path as authored ones. They are recognisably the same game rather
than a parallel system, and any verb added for the campaign is immediately
available to the generator.

### 7.1 The rhythm model

Random verb weighting produces unplayable courses — not because the verbs are
wrong but because the *pacing* is. A course that is all Tier 3 is exhausting and
unreadable; a course with no pressure is boring. The generator therefore does not
pick verbs directly. It picks a **tension curve** and then satisfies it.

**Curve shapes** (selected per seed): steady climb, double peak, late spike,
sawtooth, front-loaded.

**Generation loop:**

1. Choose a curve shape and a target duration (60–120 s, or unbounded for
   Endless).
2. Sample the curve at segment intervals to get a target `intensity` per beat.
3. For each beat, select from verbs whose `intensity` is within tolerance,
   filtered by the region's vocabulary and the adjacency rules.
4. Enforce **rest beats**: after any two consecutive beats above 0.7 intensity,
   the next must be a `recovery` verb. This is the single rule that most
   separates a generated course that feels designed from one that feels random.
5. Track a **running speed estimate** across the sequence. If a verb's
   `requires_entry_speed` exceeds the estimate, substitute or insert a builder
   verb before it. Prevents the generator's version of the bug we already hit
   once: a jump the player cannot reach with the speed the course gave them.
6. Place pickups along the estimated line, and a mastery collectible on the
   highest-intensity beat.

### 7.2 Seed validation

Generated courses are **proven traversable before they are served**. The autopilot
probe already finishes a course headlessly in seconds and reports traversability,
speed band, stall points, respawn count and finishing time — which means the
generator can be gated by automated QA without pretending that perfect autopilot
execution is the same thing as human readability.

**Accept a seed only if:**

| Check | Threshold |
|---|---|
| Autopilot finishes | required |
| Respawns | ≤ 1 |
| Stall ticks | 0 |
| Average speed | within the region's expected band |
| Duration | within ±20% of target |
| Rejected-seed rate | monitored; a spike means the verb table drifted |
| Human-tolerance probe | required once implemented: survives steering noise + 150–250 ms reaction delay |

The **human-tolerance probe** is the second gate. It runs the same course with
bounded steering noise, delayed reactions and imperfect line choice. A segment
that only the perfect autopilot can clear is technically traversable but not fit
to ship; reject it before a player ever sees it.

Rejected seeds are discarded and regenerated. Medal times for accepted seeds are
derived from the probe's finishing time using the same ratios as authored courses
(author 0.84×, gold 0.96×, silver 1.10×, bronze 1.31× of the autopilot time).

This is unusual and worth protecting: automated QA for procedural terrain fell
out of building the diagnostic, and it is what makes shipping generated content
safe for a solo dev.

### 7.3 Where generation applies

- **Daily Descent** — one seed per day, globally shared, validated before
  publication. The first completed attempt is permanently recorded as **First
  Sight**; after that the player may retry without limit on the normal Daily
  leaderboard. Seed sharing keeps the board fair while preserving the game's
  core obsession loop instead of rationing it to one attempt.
- **Endless** — continuous generation with intensity rising across prestige
  tiers, validated in a rolling window ahead of the player.
- **Authoring assist** — see §17.

The campaign stays authored. Teaching structure is intent: something has to
decide that Threshold 2 introduces exactly one bank and one split, and that the
mastery route rewards speed protected three sections earlier. Generated versions
of authored intent read as arbitrary, and arbitrary is the one thing this genre's
audience will not forgive.

### 7.4 Why both modes make the player better

Authored courses test the full stack: read the line, memorise it, optimise it.
Generated courses remove memorisation and leave pure sight-reading. That is a
different exam on the same subject, and the skill transfers — players who grind
Endless get measurably better at first attempts on new authored courses. The two
feed each other rather than competing for the same player time.

---

## 8. Course architecture

**Five regions × five courses = 25 authored courses at v1.** 60–120 seconds each.

Region gates open on cumulative medals, in the Trackmania pattern — enough that
progress is felt, low enough that nobody grinds a wall.

| # | Region | Introduces | Character |
|---|---|---|---|
| I | **Threshold** | crest, patch, split, tunnel | Learning the mountain. Wide, forgiving, fast. |
| II | **The Combs** | compression, chicane, conveyor, hazard | Rhythm. Banks in sequence, speed as a resource. |
| III | **Skyfall** | shaft, updraft, transfer, bank_to_wall | Air. The no-jump game's aerial chapter. |
| IV | **Needlework** | ridge, avalanche; advanced funnel/narrows variants | Precision. Thin lines, real consequence. |
| V | **The Throat** | corkscrew, fullpipe | Synthesis. Orientation, commitment, long descents. |

Each region ends with a **Descent** — a 3–4 minute course chaining that region's
full vocabulary, with its own leaderboard and a higher medal bar.

**Difficulty curve:** courses 1–2 of each region sit below the region's baseline
so the new verb is learned in comfort; 3–4 are the region's real work; 5 is the
Descent.

Each region also defines a **generator vocabulary** — the verb subset and
intensity band the procedural modes draw from when generating "in the style of"
that region.

## 9. Modes

| Mode | Description | Why it exists |
|---|---|---|
| **Campaign** | 25 authored courses across 5 regions, medal-gated | The spine |
| **Time Trial** | Any unlocked course, ghosts, leaderboard | Where the hours go |
| **Score Attack** | Flow chain + pickups, no time pressure | Rewards the harder line |
| **Survival** | Continuous multi-course descent, limited lives | Borrowed from Slideverse's structure; makes consistency the skill |
| **Daily Descent** | Seeded generated course; permanent First Sight result + unlimited retries on the Daily board | Sight-reading prestige plus the retry obsession loop |
| **Endless** | Infinite generated descent, prestige tiers | Long-tail sight-reading |

## 10. Multiplayer

**v1: asynchronous.** Personal-best ghost, author ghost, rival ghosts from the
leaderboard, and the Daily's global board. Cheap, matches the infrastructure
already stubbed behind `ShellBridge`, and ghost racing is the proven retention
loop for this frame.

**First MP feature after v1: local split-screen, 2–4 players.** The design's most
distinctive claim is that two players take visibly different lines through the
same course — that is a spectator property, and it only pays off with people in
the room. Camera work needs a restrained per-viewport variant.

Real-time online racing is a later consideration and should not shape v1
architecture beyond keeping the run loop deterministic, which it already is.

---

## 11. World and fiction

**The Shelf.** A continent-scale descending structure — layered stone and glass
terraces, half geology and half architecture, left by something that is no longer
here. It has no summit anyone remembers and no confirmed bottom. Down is the only
direction that exists.

Riders descend it. That is the whole fiction.

This is deliberately minimal, and it earns its place three ways:

1. **It justifies impossible geometry.** Corkscrews, full pipes, vertical shafts
   and funnels need no explanation on an artificial structure. A natural mountain
   would make every Tier 4 verb feel like a cheat — and it would make generated
   terrain feel wrong, which matters more once §7 is shipping content.
2. **It needs no characters.** No cast, no dialogue, no rigging, no animation —
   which is exactly where solo-dev 3D projects die.
3. **It gives the regions identity for free.** Threshold, The Combs, Skyfall,
   Needlework, The Throat are places on a structure, not biomes requiring
   distinct art pipelines.

Story is delivered environmentally and optionally: the deeper you go, the more
the structure looks intentional. No cutscenes, no narrator.

## 12. Art direction

**Error-absorbent by construction.** The style is chosen so that the things that
are hard to get right — anatomy, faces, realistic materials, animation — do not
appear in the game at all.

**Core look:**

- **Void ground, emissive edges.** Near-black environment. Track geometry reads
  through emissive rails, edge lines and gradient surfaces rather than textures.
- **Surfaces are colour, not material.** Each surface class has a fixed hue;
  players read friction at a glance from 200 metres out. Functional first,
  stylish second — and it means generated terrain is legible with no art pass.
- **The rider is an abstract form.** A board and a suggestion of a body, lit from
  within. No face, no cloth, no rig. Orientation and lean carry all the character
  animation would.
- **Motion carries the frame.** Afterimages, trails, spray, screen-space speed
  cues. At 200 km/h, the player is not looking at models.

**Flow drives the palette.** This is where the SLU visual identity work — colour
inversion, afterimages, tri-colour glow — becomes a mechanic rather than a
decoration:

| Flow tier | Treatment |
|---|---|
| — | Single cool hue, short trail |
| WARM | Trail lengthens, second hue enters |
| LIT | Full tri-colour glow, afterimages on the rider |
| BURN | Afterimages on the terrain edges, chromatic separation |
| INVERT | **Colour inversion across the scene.** The mountain flips. |

INVERT is the reward. Unmistakable, earned only by sustained clean momentum, and
it is the clip people post.

**Production note:** every element above is achievable with procedural geometry,
emissive materials and post-processing. No asset pipeline dependency on
modelling, sculpting, rigging or hand-painted texture work.

## 13. Audio

Momentum games live and die on audio, and this is the strongest available lever
on the project. Treated as a pillar, not a polish pass.

- **Surface audio is the primary speed cue.** Each surface class has its own
  friction voice, pitched and filtered continuously by speed. Players should be
  able to close their eyes and know what they are standing on and roughly how
  fast they are going.
- **Wind and pressure** scale with velocity and handle the top of the range where
  surface audio saturates.
- **Adaptive score.** Stems layer in per Flow tier — losing Flow strips the mix
  audibly, which makes a mistake *sound* like a mistake before the player has
  read the telemetry.
- **The Flow ladder** has its own tonal motif ascending through the tiers, and
  INVERT has a distinct signature.
- **Silence on failure.** A bonk ducks the mix hard. The absence is the punish.
- **Original OST**, region-themed, written against the adaptive stem structure
  from the start rather than composed and then cut up. Generated courses inherit
  their region's stems, so procedural content needs no bespoke music.

## 14. Teaching

No tutorial text and no gated intro sequence. The course teaches.

- **Threshold 1** is a single slope with a crest at the end. Nothing else. The
  player learns that gravity accelerates and terrain launches.
- **Threshold 2** adds one bank and one split. The player learns that turning
  costs, and that there are two ways down.
- Each subsequent course isolates one new idea before combining it.
- **The author ghost is the tutorial.** Players watch the correct line rather
  than reading about it. Available from the start on every course.
- **The results screen is the feedback loop.** Rank broken into four axes tells
  the player exactly which skill is lagging, and the next medal target tells them
  exactly what it costs.

## 15. Session and UX

- Course length 60–120 s. Region Descents 3–4 minutes.
- Session shape: 5–15 minutes, dozens of retries.
- **Retry under one second, always.** No transition, no fade, no results screen
  between attempts unless the run finished.
- Checkpoint respawns carry forward momentum so no restart faces a feature it
  cannot clear.
- Telemetry overlay available to players, not just developers — this genre's
  audience wants the numbers.
- **Camera contract:** normal play is a chase view behind the rider, aligned to
  velocity rather than body facing. A course start may deliberately begin with
  the rider coming toward camera, then swivel 180° during the countdown into the
  chase position. During Phase 0, freeze one conservative camera preset while
  tuning the motor; after the motor locks, tune camera feel deliberately rather
  than changing both systems at once.

## 16. Platforms and controls

**PC (Steam) is primary.** Controller and keyboard, both first-class. The
control scheme is one analogue axis plus two modifiers, which is unusually
portable.

**Mobile is viable and worth taking seriously.** One-thumb steering is genuinely
sufficient; tilt is a secondary option. The build already targets Godot's mobile
renderer and the art direction is fill-rate-light by design. The open question is
v1 or v2 — it affects UI layout work more than anything technical.

| | Function |
|---|---|
| Stick X / A·D | Steer — bends the velocity vector |
| Stick Y / W·S | Weight transfer on ground; lean/extend in air |
| Shoulder / Shift | Tuck — drag down, fall faster, tighten the line |
| Face / Space | Brake |
| Face / R | Retry |

No jump.

---

## 17. Production

### Implemented in the current build

The full-GDD implementation pass now contains the permanent Movement Lab, SM64
reference and production motors with instant A/B, rider-anchored camera and
countdown swivel, Flow/INVERT, the procedural audio spine, all 24 terrain verbs
and their metadata, the five-region / 25-course campaign catalog, medal gating,
Campaign Mastery Rank, PB and author-guide ghosts, records/persistence, cosmetic
progression, Campaign / Time Trial / Score Attack / Survival / Daily / Endless,
the tension-curve generator, structural seed validation, physical CourseProbe,
human-tolerance probe, developer course inspector, mobile controls, region Shelf
art language and the local leaderboard implementation behind `ShellBridge`.

The previous camera build passed `Tools/verify.sh` on the development Mac. This
full-GDD expansion was authored in a runtime without a Godot executable, so the
new revision is **implemented but not yet locally engine-verified**. Run
`Tools/verify.sh` first, then `Tools/verify-full.sh` to safe-line probe all 25
authored courses. Those results, followed by human playtesting, are the gate
before any claim that the content is tuned or release-ready.

### Generate-probe-tune: the authoring pipeline

The generator is a content tool before it is a mode. Filling five regions by hand
is the part of this plan most likely to slip, and this is the mitigation.

1. Generate 50 candidate verb lists overnight against a region's vocabulary and a
   spread of tension curves.
2. Probe all 50 headlessly. Discard anything that fails §7.2.
3. Rank survivors by speed profile, rest-beat placement and duration fit.
4. Open the best five in the **developer course inspector** — reorder verbs,
   edit segment parameters, regenerate individual beats and hot-reload without
   touching raw dictionaries.
5. Hand-tune those survivors into authored courses — add the mastery route, place
   pickups with intent, tighten the medal spread.

Editing five good drafts is a different job from writing 25 courses from a blank
file, and it is the difference between the content plan being realistic and being
aspirational.

### Build order

| Phase | Work | Gate |
|---|---|---|
| **0** | Feel pass in the Lab. Lock the movement contract. | You can name the preset and stop changing it. |
| **1** | Flow system + audio spine (surface voices, adaptive stems). | Momentum is legible without looking at telemetry. |
| **2** | Verbs 9–16 (Tier 1–2), verb metadata table, art direction pass. | A course built from new verbs feels different, not decorated. |
| **3** | Generator: rhythm model + seed validation + developer course inspector. Generate-probe-tune online. | 50 seeds produce 5 courses worth hand-tuning without raw-data friction. |
| **4** | Region I complete (5 courses) + campaign shell + gating. | Five courses hold a 30-minute session. |
| **5** | Verbs 17–24 (Tier 3–4), Regions II–III. | Tier 4 verbs read at speed without confusing the camera. |
| **6** | Regions IV–V, Descents, Survival. | 25 courses, full curve. |
| **7** | Leaderboards, Daily, Endless, prestige. | Retention loop closes. |
| **8** | Audio finalisation, OST, INVERT polish, release systems. | Ship. |

Split-screen and the **public** course editor follow v1. The internal developer
course inspector ships during Phase 3 because the procedural authoring pipeline
depends on it.

### Full-GDD pass boundary

The runtime architecture for Phases 1–8 is present in this revision, but build
coverage is not the same thing as shipped quality. The following remain external
or validation-dependent rather than silently marked complete:

- **Phase 0 feel lock:** requires controller playtest; `max_speed`, steering,
  landing retention and weight-transfer timing remain tunable.
- **Medal calibration and course hand-tuning:** generated/default author times
  are starting targets until the physical probe and human runs calibrate them.
- **Final adaptive OST:** the procedural audio spine and Flow hooks are built; the
  authored region stems are a music-production deliverable.
- **Global leaderboard service:** `ShellBridge` supplies persistent local boards
  and the service seam; hosting/authentication are deployment work.
- **Release QA/accessibility/platform certification:** must follow real-device and
  controller/mobile testing.

This boundary is intentional: no missing architecture should block playtesting,
but no untested system is labelled finished merely because code exists.

### Open calls

1. **Title.** *Let's Slide* is the working placeholder.
2. **Mobile at v1 or v2.**
3. **`max_speed` is currently 62 m/s (223 km/h) against the SM64 reference's 30.**
   A deliberate arcade choice, not yet a validated one. Phase 0 settles it.

---

## v1.3 — 174 BPM authoring contract

The campaign is authored on a **174 BPM, 4/4 bar grid**. Course specs store
`bars`; metres are derived only when `TrackBuilder` builds geometry, using
`MotorParams.author_avg_speed` as the single longitudinal scale authority.
This lets the feel pass change the target speed without destroying authored
phrase structure.

- Teaching courses: 20 bars (~27.6 s musical duration).
- Standard courses: 32 bars (~44.1 s).
- Region Descents: 64 bars (~88.3 s).
- Every segment begins on the half-bar grid.
- `TrackBuilder.beat_map` records each segment's start bar for the future
  adaptive OST.
- Campaign courses are serialized `CourseData` resources in
  `content/courses/`; `CourseCatalog` is bootstrap/fallback only.
- Five forms replace the old shared nine-beat skeleton: `steady_climb`,
  `double_drop`, `late_spike`, `sawtooth`, `front_loaded`.
- Each course has one written `signature_moment`.
- Region I is hand-authored as five distinct courses. Regions II–V remain
  musical-form bootstrap content until promoted through generate → probe →
  human-probe → F4 hand-tune.
- Medal targets for promoted authored courses come from physical probe times,
  never course-length formulas.
