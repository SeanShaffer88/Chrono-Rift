# Character and animation polish

The pre-implementation target is images/character-polish-concept.png, with all
three original heroes and run/attack/dodge silhouettes. The final label edit uses
**Riftwarden** as one word. The user confirmed no existing player saves, so the
internal ID is also `riftwarden` and save schema becomes 2; no legacy-ID migration
is added. Old alpha files are preserved/unsupported by the existing save policy.

## Models and weapons

Shared cached faceted unit meshes replace the previous voxel-like boxes. Head,
hands, sleeves and boots use rounded silhouettes; the tunic/belt/scarf use tapered
forms. Eyes, nose, brows and bracers add readable detail. Original cut silhouettes
replace the hanging hair/coat/cape blocks. Riftwarden uses an ivory V mask, muted
emerald slits, dark hood and crimson split cape. Adventurer keeps brown hair/teal
scarf/leather; Swordsman keeps long silver hair/dark split coat/shoulder guard.

The wrench has a faceted stem/grip; swords gain tapered tips, guards and handles.
Riftwarden retains a linked chain and curved crescent blade. Eight links are now
one MultiMesh draw batch. Materials and geometry are cached; no external model
pack, skeleton dependency, extra collision body or shader package is introduced.

## Presentation contracts

character_motion.gd computes purely cosmetic poses. The model owns cached nodes,
rest transforms, role indices and a reusable pose buffer. Walk/run strides,
arm swing, torso anticipation/follow-through, compact dodge, short local damage
recoil and secondary cloth/hair motion affect only artwork. Switching resets
phase/recoil; idle plants feet. A separate damaged signal requests presentation
only after accepted damage; loading HP does not produce a false hit reaction.

The character root, facing, collider, WeaponPivot, WeaponHitbox, combo/dodge
durations, damage windows and durability logic remain controlled by the existing
gameplay scripts. No motion curve scales the damage collider or changes reach.
The save system stores persistent actor state, not transient animation phases.

## Tuning and validation

1. Open character_motion.gd. Tune stride's 0.55 amplitude and 0.025 body lift first;
   keep idle stride at zero. Preview moving at the existing 6m/s movement speed.
2. Windup/active/recovery pose weights follow the existing normalized combat phase;
   change these weights for emphasis without editing melee_hero.gd timing tables.
3. Dodge height -0.22 and torso lean 0.55 are cosmetic. Check feet/cape against the
   ground; retain the original physical collider during the dodge.
4. Recoil decays at 6 units/second in stylized_character.gd. Keep it brief enough
   to read feedback without obscuring the controller's actual state.
5. Cloth uses cached role indices. Keep its rotation small enough to avoid major
   body/weapon clipping. There is no cloth physics solver or extra texture fetch.
6. Compare actual screenshots from tests/fixtures/character_polish_fixture.gd in
   Compatibility and Vulkan Mobile; this captures front/back and action poses for
   all heroes. The new native suite verifies cosmetics cannot move damage geometry,
   node counts remain stable, reset/recoil behavior and the single-word identity.

The concept sheet is an aspirational target; actual geometry remains simpler.
Android emulator verification is separate from physical-phone performance.
