# Gameplay decisions and limits

- Target the first Dark Cloud's dungeon/recovered-part/Georama loop. Use original
  characters and assets. The mobile construction-card concept was superseded by
  the approved classic command-menu concept in `images/georama-concept.png`.
- Keep the established Godot/GDScript architecture. Engine pin: `.godot-version`.
  Portable editors, SDKs, debug keys and personal notes stay outside source control.
- Battle Wrench is protected on break. Ordinary weapons are lost. Build-up keeps
  trained stats, refills target WHP and adopts the target's break policy.
- The first town has 19 finite parts. Foundations can be placed incomplete;
  completed assemblies lock. Residents require completed, placed homes. Requests
  are discovered through in-person dialogue; services have unlock state.
- User-requested prototype shortcut: enter town from a dungeon button and return
  to the exact paused floor/position. This differs from the original's travel flow.
- Town edit/walk modes share physical geometry. A separate viewport isolates its
  physics from the paused dungeon. Placement previews commit atomically or cancel.
- Runtime state is session-only. Disk saves, enemy AI, full merchant/storage
  interfaces, story cutscenes, weapon ABS/attachments, final art/audio and physical
  ARM64/16 KB runtime testing remain. No production-readiness claim is made.
- Native libraries and APK ZIP alignment have been checked for 16 KB alignment;
  the local API 36 x86_64 emulator uses 4 KB pages. Emulator performance is not a
  physical-phone performance benchmark.

The original instruction manual was used to verify menu/assembly/request concepts:
[Dark Cloud US manual transcript](https://manuals.plus/m/4c483da0d30cc39b5f6d22bcb97a2dcb62a0daca3bd2d4c344ba899f19e9ec12).
