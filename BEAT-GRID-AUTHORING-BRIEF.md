

Plain version of what I found:

You have all the machinery and none of the game. Every system works. But there's no art, no music files, and the 25 courses aren't really 25 courses. Two are hand-built. The other 23 all come from the same nine-step pattern with different pieces swapped in. Players will notice by course four.

Before anything else: open it in Godot and run `Tools/verify.sh`. It's never been run on a real engine. Then sit in the Lab with a controller and settle on how fast the rider goes, and don't change it again. Every course length and medal time depends on that number.

Now the three things you asked about.

---

### Art style

Right now the plan is black void with glowing neon edges. It works and it's cheap. It's also what every indie speed game looks like. Trackmania, Thumper, Audiosurf, a hundred synthwave racers. You said you want something ownable, and that isn't it.

Here's what I'd do instead, for the same cost or less.

**Draw the mountain as a topographic map.** Contour lines, elevation bands, survey marks. The whole world is a living map you're falling down.

Why this is the right one:

- It's literally your game's thesis. Your pillar is "terrain is the moveset." Contour lines *are* terrain data drawn as art.
- It's functional. Lines bunch up where the slope is steep. You can read how fast a section will be from 200 meters out, by eye, before you get there. That's the readability rule you already wrote into the GDD, done better.
- Speed reads beautifully. Lines streaming past you is the cheapest, clearest motion cue there is.
- It's lines, not textures. Cheaper than the neon plan, and it runs on a phone.
- Nobody has it.

Flow tiers then become: the map gets annotated as you heat up. Survey marks appear, elevation numbers light up, contour lines start pulsing. INVERT flips it from dark field to blinding white paper. That's the clip people post.

Palette: deep navy field, bone-white contours, one hot accent per region. Rider is a solid shape with no lines. The one thing on screen that isn't drawn like a map.

### Audio

You're a musician. That's the only advantage here nobody can copy, so build the game around it instead of bolting music on at the end.

**Put the terrain and the music on the same clock.**

Pick a BPM per region. Once you've locked the rider's speed, one beat equals a fixed distance down the track. Say 140 BPM at 44 m/s gives you about 19 meters per beat. Then make the course generator only produce segment lengths that are multiples of that distance.

What you get:

- Crests land on downbeats. Every single time. Automatically.
- Chicanes sit in the pocket.
- Generated courses are on-beat for free, forever.
- A good run *sounds* like a good run, because the player is unknowingly playing along to the track.

This is one change to `VerbLibrary.default_segment()` and it makes the whole game feel composed instead of assembled.

Stems per region, five files each: bed, low, mid, high, invert. They layer in as Flow climbs. Losing Flow strips layers off, so a mistake is audible before the player looks at anything.

Do this after the speed lock, not before. If the speed changes, the beat distance changes and you'd rewrite everything.

### Real course generation

The pipeline to fix this is already built into the project. It has just never been run.

The problem is one line in `CourseCatalog._spec_for()`. Every course uses this skeleton:

`straight → intro verb → support → intro verb → bowl → support → intro verb → drop → straight`

The fix is two parts.

**Part one: give courses different shapes.** Instead of one skeleton, write five or six. A course that's all rhythm with no rest. A course that opens fast and ends technical. A course built around one huge feature in the middle. A course that's a long single descent. Each region gets a mix. That alone kills the sameness.

**Part two: actually run the generate-probe-tune loop, on Region I only.**

1. Generate 50 candidates against Region I's vocabulary
2. Probe all 50 headlessly, throw out the failures
3. Open the best five in the F4 inspector
4. Hand-edit those five until they're good
5. Set medal times from real probe runs, not the `length / 32` formula

Five real courses. That's your test. If you don't want to replay course 3, the answer isn't more regions.

---

Want me to write this up as a task brief you can hand straight to Claude Code? I'd split it into three jobs it can run in sequence: the contour renderer, the beat-grid segment lengths, and the Region I generation pass.

I've opened it before. Not that I'm trying to avoid locking in the feel, but the UI and the game doesn't necessarily feel together enough to tweak it. I think we need to get region 1/the 25 levels/pretty much all the rest of the game otgether before we tweak feel... TBH I did some research and the SM64 Slide song is around 174 (DNB tempo) and I have tons o songs in that bpm range... I think we can do some genius level building from this point, with that in mind
As far as art, I largely agree with what you said for now; I think one of the best things about the SM64 Slide genre and the mods is the coloful vibrance, so we can touch into that later.
Even GPT thinks we can get to a solid 1.0 in about a day... lets do it

GPT:
Claude’s review is basically right, and I agree with your “solid day” instinct if we define completion as a playable, coherent 1.0 candidate—not a fully polished commercial launch build.
The most important part of the review is the course-content diagnosis. Right now the architecture is deep, but the 25-course campaign is not really 25 authored experiences. Claude found that only two are hand-authored while most of the rest share the same nine-beat skeleton with swapped verbs. That is the single biggest thing keeping the game from feeling finished.
I also agree with the proposed order: verify, lock feel, then make Region I real before touching more systems. The good news is that we’re already past the “does this architecture exist?” stage. We’ve actually run the verifier and started finding real traversal problems, so this review is no longer theoretical.
Where I’d modify Claude’s take slightly is the “code is finished” phrasing. The systems are substantially present, but we still have evidence of implementation cleanup needed—like strict verification, generator integration, and broken course probes. So I’d say:
The feature architecture is largely finished. The game-content layer is not.
That’s a more precise description.
On the art direction, I think Claude is very strong here. Flat/desaturated geometry, brightness-coded surfaces, one accent hue per region, saturated rider, strong horizon readability—that all fits the speed of the game and avoids wasting production time on texture detail nobody will read. I would keep the earlier “Shelf” identity, but execute it through this cleaner readability-first rule set.
The audio proposal is probably the most exciting thing in the review. The idea of putting terrain and music on the same tempo grid is excellent. At a locked movement speed, distance becomes time, so crests, banks, tunnels, and rhythm sections can be placed in musically meaningful intervals. That could genuinely become one of the things people remember about the game, rather than just a nice adaptive soundtrack.
And Claude is absolutely right that the generator should produce saved course files, not transient code-generated specs. That is the structural unlock for fast authoring. Once courses are data files, we can generate 50, keep 5, edit them, attach one memorable “moment” to each, and stop pretending generic output is authored content.
So if we wanted to finish the game in one concentrated day, I’d do this:

- Morning: get strict verification completely green and lock the movement/camera preset.
- Late morning: convert campaign courses from code-computed specs into saved data files.
- Midday: generate/probe a large Region I batch, choose five strong candidates, and give each one a unique hook.
- Afternoon: hand-tune those five, calibrate medals from real probe times, place score/mastery routes, and verify again.
- Late afternoon: apply the final procedural art/readability pass and basic audio replacement.
- Evening: play Region I repeatedly, then do a campaign-wide structural pass so Regions II–V at least have varied rhythm curves, lengths, and signature moments instead of identical templates.

That gets us to something I’d call a real alpha / near-beta.
What I would not try to finish in that same day is final OST stems, global leaderboard backend, exhaustive release QA, mobile release tuning, storefront integration, and perfect polish. Those are launch tasks, not “make the game exist” tasks.
So yes: one serious day could plausibly turn this from “systems-complete framework” into “actual game.” The fulcrum is course authorship, not another mechanic.

You're right about the feel lock, and I was wrong about the instrument. You can't judge speed in a bare Lab on a test slope. Feel is a function of the whole thing — camera, HUD, audio, a course with actual shape. Judging it in isolation gives you a number that falls apart the moment it meets a real run.

But the reason I wanted it locked first was real: author 25 courses against speed X, change to Y, and every length, medal time, and now every beat position breaks.

**Your 174 finding dissolves that entire problem.** Here's how.

### Author in beats, not meters

Stop storing course geometry in meters. Store it in bars. Meters get computed at build time:

```
beat_distance = speed × (60 / 174)
```

Now speed is a *display setting*, not a content dependency. Change it from 44 to 52 at the end of the project and the whole mountain rescales uniformly. Every crest still lands on a downbeat. Nothing breaks. You get to tune feel last, exactly like you wanted, without gambling the content.

At 174 BPM, one beat is 0.345s and one bar is 1.379s:

| Avg speedPer beatPer bar (4 beats) |        |        |
| ---------------------------------- | ------ | ------ |
| 32 m/s                             | 11.0 m | 44.1 m |
| 40 m/s                             | 13.8 m | 55.2 m |
| 48 m/s                             | 16.6 m | 66.2 m |

Your current `course_01` is 367m, which at the catalog's assumed 32 m/s average is 8.3 bars. So you're already accidentally close to a musical unit. That's a good sign.

### Verbs get bar lengths

- **1 bar** — a hit. Crest, compression, gap.
- **2 bars** — a standard verb. Bank, drop, chicane.
- **4 bars (one phrase)** — a feature. Bowl, corkscrew, fullpipe, shaft.
- **8 bars** — a section.

Target course: **32 bars, about 45 seconds.** Region Descents: 64 bars, about 90 seconds.

`VerbLibrary.default_segment()` stops returning meters and returns bar counts. That's the load-bearing change and it's maybe two hours.

### Your five rhythm curves are already DNB song forms

This is the part that made me sit up. The generator has five tension curves. At 174 they map one-to-one onto drum and bass structures:

| CurveSong formCourse shape |                  |                                     |
| -------------------------- | ---------------- | ----------------------------------- |
| steady climb               | linear build     | intro → build → drop, no let-up     |
| double peak                | classic two-drop | drop, breakdown, bigger second drop |
| late spike                 | slow burn        | long roller, one massive late drop  |
| sawtooth                   | rollers          | chopped, constant switch-ups        |
| front-loaded               | drop on bar 1    | no intro, immediate                 |

That's five genuinely different course *shapes*, which is exactly the fix for the nine-beat sameness problem. Not five templates. Five songs.

And the breakdown in a two-drop course is your rest beat. The generator already enforces rest beats. It's the same thing. The system was already musical and nobody told it.

### On the one-day plan

I'd reorder GPT's list by one step. The beat-grid refactor goes **first**, before any course authoring, because it's what makes everything after it non-destructive. Then courses-to-data-files. Then generation.

Honest read on scope: a hard day gets you the beat grid, data-file courses, and **Region I genuinely real**. That's a legitimate alpha. What I'd push back on is the evening item — doing a "structural pass so Regions II–V have varied rhythm curves." That's the template mistake at higher resolution. Five great courses beat 25 stamped ones, and you can't tell which is which until you've played Region I twenty times.

Also flag: you've already hit broken course probes. Verification could eat four hours on its own. Sequence content work so a debugging rabbit hole doesn't cost you the day.

Art: agreed, park it. The vibrant mod-palette instinct is right and it'll be a better decision once courses have shape.

Let me write the Claude Code brief.

Three phases with gates. Drop it in the repo root and point Claude Code at it.

Two things I found while writing it that matter:

**`CourseData.spec`** **and** **`tension_curve`** **are missing** **`@export`****.** That's why courses can't exist as data files — they're declared as plain `var`, so they don't survive being saved as a `.tres`. Two words of a fix, and it's the thing blocking the whole data-file plan GPT and I both want.

**The verb bar table is a musical reading of your existing meter values**, not a redesign. A `gap` at 14m becomes half a bar. A `corkscrew` at 190m becomes four bars. Your verbs were already roughly on a grid — this just makes it explicit and enforceable.

One judgment call I made in the brief: Phase C stops at Region I and leaves Regions II–V generated. If the five forms turn out to be the wrong five, you'd rather find that out after authoring five courses than after twenty-five.