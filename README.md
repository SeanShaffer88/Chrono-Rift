# Chrono Rift

An Android action-RPG and town builder made to play as close to *Dark Cloud* (PS2, 2000) as possible, built with Godot 4.3. The full plan is in [`docs/WFBP.md`](docs/WFBP.md).

## Status

- [x] Phase 1: engine baseline, touch controls, melee combat
- [ ] Phase 2: weapon durability and build-up
- [ ] Phase 3: procedural dungeon and Atla
- [ ] Phase 4: Georama town building
- [ ] Phase 5: Android export and CI

## Run

Open the folder in Godot 4.3 and press Play. `scenes/main.tscn` is a test arena with two training dummies.

| Action  | Touch                   | Keyboard     |
|---------|-------------------------|--------------|
| Move    | Left side of the screen | WASD / arrows |
| Attack  | ATK                     | J / Space    |
| Dodge   | DODGE                   | K / Shift    |
| Lock-on | LOCK (hold)             | L / Tab (hold) |
| Camera  | —                       | Q / E        |

## Tests

Build the import cache once, then run a test:

```bash
godot --headless --path . --editor --quit
timeout 120 godot --headless --path . -s tests/test_phase1_smoke.gd
```

Exit code 0 means every check passed.
