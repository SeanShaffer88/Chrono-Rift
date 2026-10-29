# Enemy combat and camera feel

## Encounter

The dungeon key guard now patrols, detects visible players within 10 world units,
pursues over the generated walkable grid, commits its facing during windup,
attacks, recovers, staggers and dies. It forgets an obscured player after 3 seconds
and stops pursuit outside a 14-unit home leash. Patrol speed is 1.1, chase speed
2.8. Attack timing: 0.65 s amber warning, 0.18 s active damage, 0.75 s recovery;
stagger lasts 0.28 s. Each swing can acknowledge one 12 HP hit per player.

Player and enemy hits use the existing Hitbox/Hurtbox acknowledgement contract.
Both now check environment occlusion and source life before accepting damage.
Rejected dodge contacts can retry during the active window, accepted contacts
deduplicate, and interruption/death immediately disable logical damage before
deferred monitoring updates. Weapon wear only follows an acknowledged hit.
The original training arena retains stationary dummies for controlled tests.

Defeat shows Retry floor. It restores HP and regenerates the same floor/seed
while preserving character, inventory, weapon wear and collected town parts.
The guard and ordinary healing pickups reset; already-collected town parts do
not respawn. Alive players cannot invoke retry. No disk save/load is introduced.

## Camera and controls

- Drag unused right-side screen space to orbit 360 degrees and tilt. UI buttons
  retain touch ownership. Focus loss/canceled touch releases the camera gesture.
- Q/E orbit on keyboard. Hold LOCK (L/Tab) to acquire the nearest visible enemy;
  hold it while pressing NEXT (C) to cycle visible targets. A cyan marker identifies
  the target. Death, occlusion and leaving retention range release targeting.
- Lock-on gently follows target yaw with a collision-checked shoulder offset to
  keep the enemy visible beside the hero. Manual orbit temporarily takes priority.
- The camera uses a 0.24-radius sphere, 0.08 near plane and environment-only
  collision. Retraction is immediate; extension eases over time. Anchor following
  is smoothed but cannot cut through a wall, and floor transitions explicitly snap.
- If a nearby low wall would push the camera into the hero, it raises its angle
  up to 82 degrees in very tight spaces and later restores the chosen tilt. Normal manual tilt remains
  between 12 and 55 degrees downward.

## Public contracts and ownership

| Owner | API | Lifecycle / effects |
| --- | --- | --- |
| DungeonGuard | tick_brain(delta: float) -> void | Physics advances state, sensing and navigation; tests can advance deterministically. |
| DungeonGuard | try_attack_hit(area: Area3D) -> bool | Active-state, cone, life and wall checks; true only for acknowledged damage. |
| DungeonGuard | receive_hit(damage: int, source: Node) -> bool | Inherited HP/flash/signal contract; immediately enters stagger/dead. |
| DungeonGuard | hit_received(damage: int, current_hp: int) | Typed inherited signal; floor unlocks key at zero HP. |
| FloorGenerator | find_guard_path(from: Vector3, destination: Vector3) -> Array[Vector3] | Bounded grid route; invalid coordinates return empty; floor owns guard lifetime. |
| CharacterBase | cycle_lock_target() -> bool | Changes target only while lock is held and actor is alive. |
| AdventureCamera | orbit(yaw: float, pitch: float) -> void | Manual orbit and clamped preferred tilt. |
| AdventureCamera | update(delta: float) -> void / snap() -> void | Character owns rig and reusable physics query; native SpringArm positions camera. |
| DungeonManager | retry_floor() -> bool | Dead-only retry; no inventory reset; replaces old floor and collision. |

Guard hitbox, warning and club initialize in _ready and are owned by the guard.
Overlap signals maintain a small contact set; scene-wide sensing runs at 5 Hz,
navigation at most every 0.35 s. Ray/shape query objects are reused where they are
in recurring loops. Godot query result containers still allocate; zero-allocation
or real-device performance is not claimed.

Custom material presets and step-by-step Inspector instructions are in
SHADER_TUNING.md. Their fragment code has zero noise/mask texture fetches and no
conditional branches. The shader uses mathematical electricity and optional
coverage/vertex contraction for dissolve.

## Validation and remaining limits

Native headless regressions exercise actual physics hits, signal payloads,
dodge retry, wall blocking, wear, death/stagger interruption, patrol/pursuit,
navigation, lock release/cycling, camera sweep/extension/tilt and defeat/retry.
Graphical fixtures inspect warning, defeat UI and shader compilation. An isolated
temporary QA APK runs the actual encounter on Android without adding cheats or
QA entry points to the shipping APK. The shipping export excludes tests/.

This is one enemy type and a first combat/camera pass. It has no navigation mesh,
advanced crowd avoidance, ranged attacks, authored animation or persistent saves.
Android emulator results do not establish physical-phone performance.
