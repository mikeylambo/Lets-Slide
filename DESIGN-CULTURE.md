# LET'S SLIDE — Slide Culture Brief & Roadmap

Let's Slide grew out of the Super Mario 64 slide: Princess's Secret Slide, the
Cool, Cool Mountain penguin race, the Tall, Tall Mountain slide. It turns that
moment into its own genre. This brief records what that community values, what
we borrow in spirit, and what we deliberately leave behind.

## What the community shows us

- **The time target is part of the level.** Princess's Secret Slide hides a
  second star for finishing in under 21 seconds. That line turned a toy slide
  into a decades-long speedrun and TAS target.
- **Slides are a creative genre of their own.** Whole ROM hacks are built from
  slides (*Super Slide 64*, *The Slideverse*, *Slide Extravaganza*). SimpleFlips
  ran a dedicated Slide Hack Competition in 2024.
- **Online play is expected.** sm64coopdx supports up to 16 players and hosts
  community game modes, including custom race formats.
- **Tech is the fun.** Players love discovering movement tech the designers
  didn't plan for, then sharing and optimising it.

## Keep (in our own form)

| SM64 culture | Let's Slide version | Status |
|---|---|---|
| Sub-21 star | Author medal as the visible "under X" line on every course | ✅ exists |
| Hidden stars | **Chick badges**: one hidden collectible per course, drawn from Ed's emblem | planned (T2) |
| Individual-level leaderboards | Per-course boards, every time backed by a replay | foundation ✅ (T1) |
| TAS and frame-perfect timing | Tick-exact clock and bit-for-bit deterministic replays | ✅ T1 |
| Discoverable tech | Crest release, compression and tuck are real skill; skips that leave the ribbon and re-land stay legal | ✅ physics, codex planned |
| Slide hacks and competitions | Course editor plus share codes, then a community tab | planned (T3) |
| sm64coopdx races | Live 16-player ghost races (riders pass through each other), async replay duels | planned (T4) |
| Instant retry | ~100 ms retry, no load screen | ✅ |

## Avoid

- **Any Nintendo IP.** No Mario, stars, Peach, castle, textures, sounds or the
  "SM64" name in marketing. The reference motor, a private tuning comparison
  using the original constants, is now debug-only and never ships.
- **Penguin-race disqualification.** The "you cheated!" meme is funny once and
  hostile forever. Checkpoints must be generous; only true out-of-bounds counts.
- **Infinite-speed exploits.** Backwards-long-jump-style exploits are beloved in
  SM64 because the game is old and fixed. In a live competitive game they erase
  every leaderboard, so speed stays soft-capped by drag and `max_speed`.
- **Kaizo as the default.** Brutal precision courses belong in the community
  tab, not the campaign.
- **Contact racing before the basics.** Collisions need server authority. Ship
  pass-through racing first.
- **Pay-to-win.** Cosmetics never change physics (already a rule).

## Roadmap

**T1 — Integrity foundation (this PR)**
- Race clock counts physics ticks, identical on every machine and frame rate.
- Deterministic input replays (3 bytes per tick, compressed), PB replay saved per
  course, **Watch run** and **Copy run code** on the results screen.
- The simulation no longer reads the wall clock (avalanche drift used it).
- Developer tools (Movement Lab, reference model, inspector) are debug-only.
- Speedrun input display (Options → Show input display).
- Fixed: the invert-steering option was never applied.

**T2 — Speedrun suite**
- LiveSplit-style per-checkpoint PB splits and sum of best.
- Paste a run code to watch it or race it as a ghost.
- Chick badges, and a tech codex that unlocks as players discover tech.
- Full-campaign run timer mode.

**T3 — Courses as community content**
- Documented JSON course format built on the existing bar-based spec.
- Grow the F4 inspector into an in-game editor with share codes.
- Validate community courses with the existing probe before publishing.

**T4 — Multiplayer**
- Live ghost races over Steam lobbies (GodotSteam), 8–16 players.
- Async duels via run codes, and a global live Daily Descent.
- Server-side replay validation for leaderboard entries.

**T5 — Presentation**
- Onboarding, controller remapping, accessibility pass, final audio stems.
- Ed model integration once the mesh exists.

## Sources

- [Ukikipedia — The Princess's Secret Slide](https://ukikipedia.net/wiki/The_Princess's_Secret_Slide)
- [speedrun.com — PSS Sub 21 Star (SM64 DS)](https://www.speedrun.com/sm64ds/level/The_Princesss_Secret_Slide_Sub_21_Star)
- [Super Mario 64 Hacks Wiki — Super Slide 64](https://mario64hacks.fandom.com/wiki/Super_Slide_64)
- [Super Mario 64 Hacks Wiki — Slideshow 64 (SimpleFlips Slide Hack Competition 2024)](https://mario64hacks.fandom.com/wiki/Slideshow_64)
- [RHDC — Super Mario 64: The Slideverse](https://romhacking.com/hack/super-mario-64--the-slideverse--demo-)
- [Wikipedia — Super Mario 64 Coop Deluxe](https://en.wikipedia.org/wiki/Super_Mario_64_Coop_Deluxe)
- [Coop DX Mods — game modes](https://mods.sm64coopdx.com/mods/categories/game-modes.5/)
