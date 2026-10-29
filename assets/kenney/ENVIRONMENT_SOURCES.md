# Environment pass asset sources

- dungeon/: Kenney Modular Dungeon Kit **2.0**. Official page currently lists 2.1,
  but this imported archive and its included license identify version 2.0.
  https://kenney.nl/assets/modular-dungeon-kit
  Creator's download mirror: https://opengameart.org/content/modular-dungeon-kit
  Five selected GLBs plus their palette. During polish the plain template-floor
  replaces template-floor-detail; the unused original floor model was removed.
  Original CC0 License.txt retained.
- town-detail/: five selected models from the already reviewed Fantasy Town Kit
  2.0, plus its palette and original CC0 License.txt.
  https://kenney.nl/assets/fantasy-town-kit

Models are normalized for the existing world scale. Dungeon meshes are batched;
town parts stay separate for assembly, door opening and roof visibility. Textures
remain unmodified. Roof palette recoloring happens in a one-fetch material shader.
Imported decoration does not create new gameplay collision or grant town parts.

## Minimal train/factory integration

- train/: two selected GLBs from Kenney Train Kit 1.1, exact included CC0 License.txt retained. Official source: https://kenney.nl/assets/train-kit
- factory/: two selected GLBs from Kenney Factory Kit 3.0, exact included CC0 License.txt retained. Official source: https://kenney.nl/assets/factory-kit

Retrieved 2026-10-29. Original relative `Models/GLB format/Textures/colormap.png` dependencies are included unchanged; no other models, animations, PBR maps, paper bitmap or archive code are copied. The piston GLB contains three node-animation records; the landmark helper flattens its default mesh pose and never adds the imported scene or animation players to the tree.

Archive SHA256:
- train: `cf50d77e8cbacbf38dd50826d4bce5392db8e4f67373d3c4e583b0ed0e474475` (5266588 bytes).
- factory: `7e31fb2308e90304672bd15cd18fa9d9f02c03731a8cbc57a8e3e1c181dfb0a7` (4511890 bytes).

Selected GLB SHA256 (raw source counts are metadata, not measured runtime cost):
- train/train-locomotive-a.glb: `8dfe9d20667c1534652286149fb0e1639ff48975a4187d3ad2fd956add0bba2a`; 1666 triangles, 6 source primitives, 1 used material.
- train/train-carriage-coal.glb: `95c6282a6b13317640ac48bd75d7aeec10faa9bfc035ba21977bb0296df7199a`; 1184 triangles, 4 source primitives, 1 used material.
- factory/pipe-large-valve.glb: `57126374dce5b172e06d5d6f8cbaab97c9cffe3e5e726060eb14c50a5bd519b6`; 456 triangles, 1 source primitives, 1 used material.
- factory/piston-round.glb: `cd67c755d4ea6f53b5a5583447f45e9abb5d87f344d9f053820d1b09d719fcdd`; 276 triangles, 3 source primitives, 1 used material.

Exact copied palette SHA256:
- train: `e264660f3fc9ecbd642bdb7fb7b7dc10755a061560a66651baf48274c729af09`.
- factory: `35d7bd6900dde0208429eeaec87fa17fbf024ed59f3f4eab54bc92802eba9dd7`.

Adaptation: `landmark_assets.gd` reuses EnvironmentAssets nested-transform collection/bounds, samples each source material palette using its UV coordinates, bakes colors into an opaque matte single surface, and applies a restrained biome tint without modifying cached source materials. Source proportions use uniform fitting. Palette image load/decompression/UV failure skips the imported part. No custom hero, enemy, weapon or camera code is changed by this integration.

Ownership/placement: DungeonLandmarks owns the floor-local generated parts. Overgrown Rails adds one raised distant locomotive/car pair only after an exact whole-footprint distance check of at least 7 world units against every walkable cell footprint, including plinth/trim; failure adds nothing. Existing caps stay unchanged. Frost replaces the two small amber indicator bars at each of the first two valid cabinet anchors with a valve then a piston, uniformly fitted to maximum extent 0.20 inside the prior shallow envelope and top <=2.60. Existing cabinet/mount, snow cap and pipe frame remain. Other anchors remain native. A floor uses at most two imported model instances in this configuration (hard design budget four); no new physics, lights, scripts processing frames, animation, navigation or save fields.

This source was initially staged without execution. After explicit authorization, native regressions verified the palette bake, preserved nested bounds, footprint guards, frost envelope and resource ownership; actual native and Android renders are retained. One source material does not imply one draw call; the helper intends to flatten compatible source primitives, with actual palette import/rendering now verified. Runtime draw-call/frame-time and physical-phone performance remain unmeasured. Later authorized checks must verify nested bounds, palette orientation, decompression fallback, no animation/collision children, bounded cached geometry, train footprint proof, frost bounds/fallback and actual Android framing.
