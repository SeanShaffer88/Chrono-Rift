# Playable roster and dungeon companion

The Characters button is available in both dungeon and town. Its menu pauses
the scene tree and offers three original heroes with one shared combat model:

| Character | Visual direction | Protected starter |
| --- | --- | --- |
| Adventurer | Brown hair, leather, teal scarf | Battle Wrench |
| Swordsman | Silver hair, charcoal coat, shoulder guard | Duskblade |
| Riftwarden | Ivory mask, emerald eyes, crimson cape | Crescent Chain |

The swordsman and warden take silhouette inspiration from Sephiroth and Spawn;
their names, costume geometry and models are original. Concept boards are
aspirational art, distinct from current procedural in-game meshes.

Switching preserves current HP, position, camera, floor progress, thirst and
town state. Each hero retains their own inventory, equipment and weapon wear.
Switching cancels an active swing and cannot revive a dead player. Damage,
combo timings, dodge and hit range are shared. The chain is linked metal geometry
ending in a curved blade, animated by the shared melee swing; it is not yet a
physics chain, ranged grapple or separate ability. New starters have the same
base attack and durability as Battle Wrench. Evolution branches for the two new
weapon families await their own data; the original wrench branch remains.

A small dark red electrical companion follows every selected hero in dungeons.
It scans every 0.15 seconds within 3 world units of the player and requires a
clear environment ray. It collects town-part restoration orbs even at full HP,
unlocked keys after their guard is defeated, and nearby healing pickups only
when HP is below maximum. It never activates exits, collects through walls or
across town/dungeon worlds, or collects for dead players. Up to three healing
pickups per floor restore 20 HP each, clamped to maximum. Existing touch collection
continues to work. The companion is absent in town. Currency and equipment drops
are not present yet; future pickups can implement try_companion_collect.

Runtime code uses existing Godot primitives and the selected CC0 scenery;
there are no additional packages, paid services or runtime dependencies.
The roster/companion regression suite covers inventory ownership and wear,
switch cancellation, pause/resume, death, reset, radius, occlusion, worlds,
guarded keys, full-health healing and exit exclusion. Graphical capture script:
tests/fixtures/roster_visual_fixture.gd.
