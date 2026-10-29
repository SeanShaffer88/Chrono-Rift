# Enemy combat roles and encounter slice

Hunter, 40 HP: a 0.70 s crouch and arrow-lane warning commits its heading, followed by at most 2.8 units of straight motion in 0.35 s. Walls stop the dash, and one acknowledged active-window hit deals 10 damage. It cannot home during the warning or dash.

Bruiser, 60 HP: a broad fan and raised arm warn for 1.0 s; its 0.22 s strike deals 16 damage, followed by 1.1 s recovery. Ordinary hits from the front 120-degree cone are halved with ceiling rounding during patrol/pursuit/windup/active and do not stagger. Flanks, recovery and stagger are exposed. Devourer normal swallow explicitly bypasses this armor through the same reserved acknowledged pipeline. Raw receive_hit remains compatible for restoration and existing callers.

Sentry, 30 HP: a thin aim line commits at warning start. After 0.9 s it launches one straight 8-damage bolt at 7 units/s, with at most 1.8 s life and 1.2 s recovery. A full-segment environment/player-hurtbox ray consumes the bolt on the closest contact, including rejected dodge contacts. A source owns at most two live bolts, canceled on death and floor teardown.

The original 60 HP key guard retains its constants, art, attack cadence and key-death hook. The generated floor may add at most one of each role in separate safe nonspawn rooms, excluding reserved pickups/key/exit/orbs/healing. Hunter/Sentry need lanes; Bruiser needs flank space; unsafe placements skip. No role becomes a boss automatically. Floor content owns actors and bolts.

Save format 4 requires exactly three stable encounter records (hunter/bruiser/sentry) with bounded HP; skipped/dead roles use 0. Damaged/dead encounters restore without changing key-guard progress. All five strict inventories and the floor-six Devourer unlock remain. Unsupported earlier formats are preserved/blocked without migration.

Foundry keeps the classic seeded BSP layout. Frost rooms at least 7 × 7 omit their four corner cells; rail rooms become elongated within existing leaves. Existing three-cell corridors and center connectivity remain. No new cover pillars/decor were added; safe counterplay uses existing walls and room space. Native real-charge corner tests passed, so camera runtime is unchanged.

Sound feedback is four short cached native PCM cues for attack, acknowledged hit, dodge and damage, with at most four shared voices. Busy bursts are dropped; active voices are never stolen/restarted. Inspector muted/set_muted is the current mute interface; there is no new settings UI, input binding or persisted sound preference. Native test shutdown stops audio and gives the server 100 ms to retire queued playbacks before quitting. No warnings are suppressed.

Source map: scripts/combat/enemy_profiles.gd, encounter_layout.gd, enemy_projectile.gd, combat_audio.gd; scenes/characters/dungeon_guard.gd and training_dummy.gd; scripts/combat/hitbox_3d.gd and hurtbox_3d.gd; scenes/dungeon/floor_generator.gd; scripts/utilities/enemy_art.gd and bsp_tree.gd; scripts/persistence/save_data.gd and save_store.gd. Native regressions: tests/test_enemy_roles.gd plus current-format save/layout fixtures. Actual native role captures: outputs/enemy-role-native/ outside repo.

Models remain simple opaque native prototypes, less detailed than concept boards. No dependencies, new lights, shaders, textures or per-frame geometry generation were added. No physical-phone performance or sound-mix claims. Player ranged combat, core upgrades and title animation remain outside this slice.

Close on-axis melee can let the player obscure part of an enemy; warnings remain visible, and backstep/orbit reveals the windup. This slice verifies player/camera collision clearance, not full enemy visibility from every angle.
