# LET'S SLIDE — World Design

How a map gets its look, where to change it, and how to see the change in
seconds. Region I (Threshold) is the finished reference; the other four use
the same kit with first-pass palettes.

## The Shelf

A continent-scale descending structure of stone and glass terraces, standing
in a sea of cloud. Every course is a line down it. The world exists to frame
that line, so three rules stay fixed:

1. **The deck reads first.** Its hue is the surface class (friction), blended
   into the region's stone. Glass edges glow in that hue. Nothing in the world
   uses those colours at that brightness.
2. **The world sits below and beside the line, never across it.** Terraces
   step *down and away*; every block is checked against the whole course
   (`WorldKit.TRACK_CLEARANCE`).
3. **One silhouette per region.** Each region has a landmark on the horizon
   past its finish line, so every course in that region rides toward it.

## What builds a course's world

| Layer | Where | What it does |
|---|---|---|
| Region theme | `src/track/RegionTheme.gd` | Every colour, light and density for a region. Start here. |
| Deck | `src/track/shaders/deck.gdshader` | Surface hue + stone, glass edges, a lit band on every 174 BPM bar, panel joints that stream past at speed. |
| Deck underside | `TrackBuilder._add_skirt` | Gives the ribbon thickness so it reads as built, not floating. |
| Sky, sun, fog | `WorldKit.add_environment` / `add_sun` | Driven entirely by the theme. |
| Terraces | `WorldKit._terraces` | Stepped stone slabs with glass lips beside and below the line. |
| Piers | `WorldKit._piers` | Columns carrying the deck down into the cloud. |
| Far Shelf | `WorldKit._far_shelf` | Stepped massifs on the horizon for scale. |
| Gates | `WorldKit._gate` | Stone gate over the start; a larger one over the finish. |
| Landmark | `WorldKit._landmark` | The region's signature silhouette (Threshold: the great arch). |
| Cloud sea | `shaders/cloud_sea.gdshader` | The floor of the world, dissolving into fog. |
| Stone | `shaders/shelf_stone.gdshader` | Strata on faces, flagstones on tops; no textures needed. |

All blocks batch into two draw calls (stone and glass), and placement is seeded
from the course, so a map looks identical every run.

## The loop

```
Tools/world-shots.sh course_01            # → build/world-shots/course_01/*.png
```

Six fixed shots per course: three chase views (what the player sees), an
establishing shot, a vista and the finish. Change a theme value or a kit
function, re-run, compare. It runs headless, so it also works in the cloud.

## Making a region iconic (next steps)

Threshold is the template. For each other region:

1. **Tune the palette** in `RegionTheme` until the six shots read as that
   place at a glance.
2. **Design its landmark.** Add a case to `WorldKit._landmark`, e.g. The Combs:
   a honeycomb tower; Skyfall: floating spires; Needlework: a needle forest;
   The Throat: a colossal ring over the drop.
3. **Give its terraces a shape language.** Combs → hexagonal stacks, Needlework
   → thin vertical fins. `_terraces` is the one place to vary it.
4. **Signature moments.** Each course has a `signature_moment` line in its
   data. Stage it: a gate, a gap over the cloud, the landmark revealed through
   a tunnel exit.

For the Platform Fighter crossover, the landmark plus the deck language is the
transferable identity: a stage built on a Threshold terrace under the great
arch already reads as *this* world.
