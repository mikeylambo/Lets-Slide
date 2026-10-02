# Ed — Meshy pack

**Use `01_ed_front_render_TPOSE.png` alone (Image to 3D, single image).**
It's already a 3D-shaded, front-facing T-pose on white, which is what Meshy
reconstructs best. Don't mix it with the line-art images in multi-view mode:
the two styles disagree on proportions and Meshy averages them into mush.

Settings
- Topology: quad · Target polycount: ~12k (LOD0; see below) · Symmetry: on
- Texture: PBR on, "remove lighting / delight" on if offered (the in-game
  shader supplies lighting)
- Pose: T-pose · then Meshy "Auto-Rig" → humanoid
- Export: GLB

Other files
- `02_ed_front_lineart_TPOSE.png`: fallback input if 01 gives a muddy face.
- `03_ed_slide_stance_REFERENCE.png`: the riding pose. Not a Meshy input;
  this is the target the game poses him into.
- `detail_*`: reference for a cleanup pass (back of head, shoe backs).

Drop-in
- Save the export as `art/ed/ed.glb`. The game picks it up automatically
  (falls back to the stand-in rider if missing).
- Scale doesn't matter: the importer normalises height to 1.2 m, feet on the
  origin, facing +Z.
