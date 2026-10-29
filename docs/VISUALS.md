# Visual pass 1

Direction: original chunky characters inspired by Dungeon Boss silhouettes,
with saturated low-poly environments inspired by Hunt Royale. Dark Cloud
remains the gameplay reference. The approved concept is a target, not a runtime screenshot.

Implemented: original box-built adventurer with scarf, hair, eyes, boots and
walking leg motion; starter wrench jaws that disappear for the evolved sword;
chunky stationary goblin guard; small flagstones, three-course stone walls,
wall caps, restrained fog and warmer lamps; timber house details, bridge rails,
resident faces and imported faceted trees. HP and WHP bars report live state.

Selected Kenney Fantasy Town Kit 2.0 assets are CC0. Sources and original license
are in assets/kenney/. Only five models and their shared palette are shipped.
Imported props are decorative, with no generated collision. Houses retain their
existing assembly state, traversable entrance and separate roof/furniture nodes.
Floor collision, generation RNG and combat hitbox dimensions are unchanged.
Floor/wall detail uses MultiMesh batches; stone variation is deterministic and
does not consume gameplay RNG. No paid tooling or runtime dependencies added.

Validation: six headless suites, graphical dungeon/guard/town captures, debug APK
export plus signing and 16 KB ZIP alignment. Regression coverage includes model
geometry, collision-free props, unchanged hero capsule, walk/rest animation,
equipment silhouette switching and guard defeat/unlock behavior.

Remaining art work: authored skeletal animation, beveled character/stone meshes,
terrain contours, richer interiors, camera occlusion refinement, effects and
broader phone performance testing. Existing menu structure remains functional;
this is not a claim of final art quality or complete parity with the concept.
