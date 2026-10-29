# Devourer and current save format

Devourer is a secret original yellow/red folded-paper mechanical maw with one amber eye, a hinged toothed jaw and no limbs or equipment. Clear floor 6 with any hero to unlock it. Only the actual floor-exit advance records clears; generation, guard defeat, retries, town visits and character swaps do not unlock it. New game resets the flag. Existing unlocked sessions preserve it across death, visits, switching and saves.

The character card is absent before unlock. The same responsive scrolling menu gains its fifth card afterwards. Selection is also guarded in GameState, independently of UI visibility.

Devourer uses the existing three-step melee cadence, range, hitbox, LOS, dodge and acknowledged hit pipeline. Its base damage is 15. Normal living enemies explicitly expose remaining-HP swallow damage; boss actors opt in through is_boss and receive ordinary combo damage. Unknown receivers also receive ordinary damage. Hurtbox invulnerability, rejected-hit retry, receiver reservation, deduplication and normal death/key events remain authoritative. Only an accepted normal swallow starts the brief non-gory jaw cue. No enemy is directly freed and no HP is directly assigned by the attacker.

Its inventory is empty and rejects weapon storage/equipping. There is no weapon resource, durability or equipment for Devourer. Core upgrades remain a separate documented plan, not implemented mechanics.

SaveStore format is now version 3, explicitly requiring all five known inventories and boolean secret_unlocked. Devourer must have an empty inventory with equipped -1; activating it requires the flag. No older save migration or inferred unlock is supported. Unsupported files are preserved and autosave blocks rather than overwriting them. Validation uses isolated fresh QA paths.

The current model is a bounded opaque native prototype; the concept is a design reference. All geometry/materials are cached, with no extra collisions, shaders, lights or per-frame mesh generation.
