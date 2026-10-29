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
