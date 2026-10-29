# Local autosave

One profile, automatically loaded by the shipping dungeon main scene. No cloud
service or new package is needed. Native tests and QA entry points do not touch
the player's file; they opt in with separate paths and a separate Android package.
Startup restore is deferred until the root finishes scene initialization, so a
saved town visit can safely create its separate viewport and UI.

## What is kept

- All five characters' owned/equipped records (Devourer remains empty), trained attack/element/slayer
  stats, durability, break policy, active character and thirst.
- Collected restoration IDs and parts, assembled components, placements,
  rotations, resident conversations and completion. Services are derived from
  restored resident conditions on load.
- Dungeon seed/floor, player position, HP, facing/camera preference, guard health
  or defeat, gate key and consumed healing pickups. A defeated player reloads
  into the existing Retry floor flow. Retry still regenerates that same floor.
- An open town visit, editing/walking mode, town hero position and HP, and the
  paused dungeon behind it. An unfinished placement preview is not committed.

Movement/combat animations and enemy attack phases are transient; the guard
resumes in a neutral state with saved HP. Positions that no longer correspond
to valid dungeon ground fall back to that floor's spawn without changing saved HP.

## When it saves

Changes request a write after a 0.3-second settling interval. Position/thirst
also save every five seconds. App pause/focus loss and normal desktop close
request a synchronous flush. A hard kill/power loss can lose changes since the
last successful save. Android background and process-restart behavior is tested
separately from in-memory scene recreation. No claim of hardware power-loss
immunity is made.

The small HUD status line reports ready/loaded/saved, backup recovery or failure.
The layout mockup was produced before implementation. No manual slot menu is
added in this pass.

## Files and recovery

Files live in Godot's private `user://saves/` directory:

- autosave.json: committed primary
- autosave.json.bak: validated previous primary (also created on first save)
- .tmp/.bak.tmp: uncommitted files, ignored on startup

Version 2 is a JSON envelope containing a JSON payload string and its SHA256
checksum. Files are capped at 2 MiB. Read/validate the complete payload before
mutating live state. Weapon IDs map to an explicit template allowlist; saves
never choose scripts or arbitrary resource paths. Integer stat keys are stored
as fixed-length arrays. This checksum detects accidental corruption; it is not
an anti-cheat or authentication mechanism.

The character-polish alpha changes the character ID to `riftwarden`. The user
confirmed there are no existing player saves; no legacy-ID migration is added.
Version 1 alpha files remain preserved/unsupported rather than silently rewritten.

Writes flush/close and validate the temporary file, update the backup via a
temporary copy, then replace the primary with a same-directory rename. A damaged
primary never replaces a valid backup. A valid backup is loaded automatically
when the primary is missing/corrupt. Unsupported schemas and two invalid copies
block writes and keep the original files; the HUD reports that progress is not
being saved. Filesystem write failures likewise report failure and keep the last
committed data where replacement has not occurred. Do not silently reset or delete
a player's files to clear an error. The explicit schema3 boundary does not migrate old formats; unsupported files remain preserved.

Android app updates with the same package/signing identity retain private files;
uninstalling/clearing app storage removes them. This pass provides no account sync
or export UI.

## Regression and Android QA

`tests/test_save_load.gd` checks real file replacement, backup recovery, checksums,
interrupted temp files, unsupported schemas, invalid contracts, resource allowlists,
weapon stats/wear, pickup/guard/key ownership, town resume, defeat and write failures.
It uses a process-specific file and cleans up only its own known paths.

`tests/fixtures/save_mobile_fixture.gd` runs only in the isolated QA APK. A local
driver backgrounds, force-stops and relaunches that app across four launches,
checking town/dungeon persistence and a deliberately corrupt primary's recovery.
Shipping exports exclude all fixtures/tests and documentation.

Current format4 requires five known inventories and boolean secret_unlocked; Devourer has no weapon entries and requires unlock to be active. Unlock records only a real floor6 exit; no floor-number inference or old-save migration.

Format4 also requires the three bounded stable encounter HP/death records. Unknown, duplicate, missing and over-limit records reject; no earlier-format migration.
