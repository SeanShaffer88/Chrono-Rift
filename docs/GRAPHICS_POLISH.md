# Graphics polish

Target: images/graphics-polish-concept.png, generated before implementation.
The concept remains more detailed than the alpha; use actual fixture/Android
captures to assess implemented quality.

## Implemented

- Inset flagstones with narrow joints, sparse rubble accents, staggered wall
  faces/caps and a single baked masonry surface. Existing floor/wall collision
  and navigation remain authoritative.
- Up to eight deterministic room wall landmarks: copper pipe arches/valves and
  teal/russet rift banners. One opaque draw surface, no added lights or blockers.
- Folded house gables, cream fascia, awnings, door joinery, handles and window
  flower boxes. Decorations are grouped by visibility: roof additions disappear
  on interior access, door decorations follow the door leaf. Existing multipart
  ownership and the 1.5m entrance remain intact. Ornamental overhangs have no new
  gameplay collision.
- Rounded thick paper canopies alongside conifers, layered cut-paper ridges and
  tiny paper petals sharing the existing grass batch/placement coverage mask.
- Faceted restoration orbs with brass seals, recognizable medicine bottles and
  shaped gate keys. Existing collection/collision logic is preserved.
- Copper/stone exit frame and a restrained analytic rift veil. Locked gates use
  dim amber; unlocked gates use cyan, including restored save state.
- Derivative-antialiased river bands/ripples, calmer flow and tuned light balance.

Static embellishments use scripts/utilities/art_mesh.gd to bake colored primitives
into one opaque surface per required visibility group. No per-frame scene searches,
new asset packages or runtime dependencies were introduced. The one additional
selected source model comes from the already verified CC0 Kenney archive.

## New and updated shader controls

1. Run a dungeon, select its generated ExitGate/RiftGateVeil in **Remote**, then
   expand **Material Override > Shader Parameters**. Changes here are temporary;
   save an experimental material as .tres or change source defaults for persistence.
2. rift_gate.gdshader: **Rift Color** sets the veil hue, **Speed** defaults to 0.4
   (set 0 for a still inspection), **Opacity** is set by gate state to 0.18 locked
   or 0.5 unlocked. Keep opacity below 0.6; the small plane should not obscure the
   exit frame or combat. State presets live in dungeon_pickup.gd::_update_gate.
   Cast Shadow stays off. No screen/depth textures are sampled.
3. river_surface.gdshader retains **Deep Color**/**Shallow Color** for paper layers;
   **Flow Speed** now defaults to 0.35. **Ripple Strength** defaults to 0.08: set 0
   to compare flat bands, then raise in 0.02 steps. Derivatives soften distant lines
   and band boundaries to reduce mobile shimmer. Defaults live in the shader.
4. Existing paper, steam and energy controls remain in ENVIRONMENT_ART.md and
   SHADER_TUNING.md. Each new/updated shader has branch-free fragment code and
   zero noise/mask fetches (paper uses one albedo palette fetch). The veil uses
   one small transparent quad, not full-screen postprocessing.

The native graphics suite checks geometry batching/bounds/normals, draw/count
budgets, no added blockers, roof/door ownership, deterministic landmarks and gate
state after reload. Existing combat, collection, Georama and save suites also run.
Render both Compatibility and Vulkan Mobile; verify Android with actual shipping
controls and isolated combat/restored-town QA. Emulator checks do not establish
physical-phone performance.
