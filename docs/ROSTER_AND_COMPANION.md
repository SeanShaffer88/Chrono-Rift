# Playable roster and dungeon companion

The Characters button is available in both dungeon and town. Its menu pauses
the scene tree and offers four initially available heroes and one secret hero with one shared combat model:

| Character | Visual direction | Protected starter |
| --- | --- | --- |
| Infiltrator | Blond paper hair, green tunic and pointed cap, back-mounted decorative shield | Trail Sword |
| Shadowblade | Silver paper hair, dark folded coat | Buster Sword |
| Riftwarden | Ivory mask, dark hood, crimson folded cape | Red Energy Sword |
| Battlemage | Bent tan hat, blue folded coat, recessed face and warm eyes | Battlestaff |

Display names changed; internal character IDs remain `melee_hero`, `swordsman`
and `riftwarden`. Weapon IDs/resources `duskblade` and `rift_chain` retain
stats, owner inventories, wear, save records and combat hitboxes. The new
Infiltrator starter `trail_sword` copies the old Battle Wrench's stats and
build-up policy; old wrench saves and art remain supported.

Switching preserves HP, position, camera, floor progress, thirst and town state.
Each hero retains their inventory, equipment and wear. Shared damage/combo/dodge
rules remain. Shadowblade's original steel slab silhouette has a broad body,
flat spine and clipped tip. Riftwarden's old `ChainBlade` construction path now
builds a compact grip with two separated red prongs and pale inner layers; it
has no visible chain. Its opaque material uses restrained emission without
new lights, shaders, transparency, particles or bloom. These are visual changes,
not new abilities. Infiltrator keeps a straight steel blade with a blue-purple winged guard and wrapped grip; his shield is secured diagonally to the back on the body pose, leaving the left hand empty. The shield has no gameplay mechanics. Historical concept prompts are preserved; current concept
boards remain aspirational and distinct from actual in-game captures.

This art/camera pass was initially source-only; later explicit authorization
allowed native and Android validation. Updated regressions retain legacy wrench
support and verify new starter, energy prongs, body-mounted shield and camera
clearance. See outputs/Validation-results.txt for exact results and limits.

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

Battlemage uses stable ID battlemage and protected battlemage_staff, with the existing shared melee timing, hitbox and balance. Save format 4 requires all five inventories and an explicit secret unlock flag; older formats are preserved without migration. The responsive menu uses two columns at viewport widths of 680 or greater, one column below, a scrolling card area and pinned Close. Current additions have targeted native validation; full and Android validation are pending the current scope freeze.

Devourer unlocks after clearing floor6 and is weaponless. See DEVOURER.md for the strict current save and acknowledged swallow contracts.
