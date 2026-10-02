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

## Current model

`art/ed/ed.glb` is Meshy's multi-image model of Ed (task `01a0fdee…`),
remeshed to ~15.5k triangles (`01a0fedc…`) and auto-rigged (`01a0fede…`):
one skinned mesh, 24-bone humanoid skeleton, PBR textures (albedo, normal,
metal/rough) repacked to 2K/1K JPEG to keep the file at ~5.5 MB.

The game poses the skeleton procedurally (`src/player/EdRig.gd`): a
side-on, regular-footed board stance with the shoulders opened toward the
nose, IK-planted feet, a low tuck, and arms thrown wide in the air. Meshy's
baked animation clip is not used. Any GLB with the same Meshy bone names
gets the stance; other models are shown as authored.

To replace the model: rig it in Meshy (remesh to <=300k faces first), export
GLB, and overwrite `art/ed/ed.glb`. `preview_ed_ingame.png` is the
`-- --ed-preview` render.
