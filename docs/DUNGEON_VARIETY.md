# Expedition variety and editor defaults

New expeditions select a native signed 32-bit seed once, only when storage is genuinely missing or the player explicitly confirms verified backup and fresh start. Existing saves, retries, floor advances and town returns retain their seed. Failed initial writes retain the chosen in-memory expedition for retry; blocked files never trigger a fresh save. Save format remains 4.

An independent seeded decoration stream shuffles safe wall anchors and three small motifs per biome. It decorates at most eight rooms without modifying BSP generation, gameplay RNG, combat, pickups or collision. Existing art, palettes and imported assets remain unchanged. At most two cached floor-owned transforms animate valves, piston travel or leaves inside the prior authored decoration envelope. Pausing stops animation; teardown restores and releases owned references. Imported models remain bounded by the existing four-model ceiling; no assets were added.

Georama editing now starts at the gameplay isometric angle (45° yaw, −55° pitch), orthographic height 14 and distance 14, centered on the walking hero. Orbit, tilt, pan, pinch, wheel zoom and building rotation remain available. Refreshing UI preserves adjustments; walking back into editing restores the default. Zoom spans 8–110. Walking gameplay remains fixed.

Native regressions cover failed writes, blocked saves, transaction failure, deterministic retry, RNG isolation, safe anchors, motif bags, animated bounds and phase continuity, plus editor control persistence and placement projection. Android validation uses a separate QA package and preserves shipping saves. Procedural scenery remains a modest prototype; no new difficulty, rewards, sound or dependencies are introduced.
