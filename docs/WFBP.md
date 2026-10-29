# Chrono Rift — Comprehensive Workflow Blueprint (WFBP v2.0)
### Dark Cloud–Inspired Action-RPG & Georama Builder for Android (Godot 4.3 Engine)

---

## 0. Fidelity Target

*   **Reference game:** *Dark Cloud* (PlayStation 2, 2000). Gameplay loops, systems and controls should match it as closely as an Android touch game allows: dungeon floors with Atla to recover, a thirst gauge, weapon durability (WHP) with weapon level-up and build-up, ally characters with distinct weapons, and Georama town rebuilding with resident requests.
*   **Where the blueprint deliberately differs, it says so** (look for "Deviation:"). Anything not marked should follow Dark Cloud's behaviour.
*   **Original content only:** mechanics are copied, names/characters/story/art/music are not. Before any public release, replace Dark Cloud-specific terms (e.g. "Atla", "Georama") with original names.

---

## 1. Executive Architecture & Engine Mandates

*   **Engine Target:** Godot Engine **4.3-stable** (`gl_compatibility` mobile rendering backend).
*   **Target Platform:** Android (Min SDK 24, Target SDK 34, 64-bit ARM `arm64-v8a` primary target).
*   **Viewport & Resolution:** Landscape, Base Canvas `1280x720`, Stretch Mode: `canvas_items`, Aspect: `expand`.
*   **Plain-Text Asset Contract:**
    *   No binary scene or project dependencies. All scenes (`.tscn`), resources (`.tres`), and scripts (`.gd`) are plain text.
    *   Zero external asset blockers: All geometry, characters, items, and structures generate procedurally via `PrimitiveMeshFactory` using standard flat-shaded materials until custom `.glb` meshes are dropped into `assets/`.
*   **Decoupled Signal Infrastructure:**
    *   Autoloads (`EventBus`, `GameState`) are globally accessible, but all event-emitting scripts must guard access (`if is_instance_valid(EventBus):`) so scenes can be instantiated in test harnesses without requiring autoload initialization.
*   **Headless Test Harness:**
    *   All unit and integration tests live in `tests/` and extend `SceneTree`.
    *   Tests run via `godot --headless --path . -s tests/<test_script>.gd` and conclude by calling `quit(0)` on success or `quit(1)` on assertion failure.
    *   **Import first.** `class_name` globals only resolve from the `.godot/` cache, so run `godot --headless --path . --editor --quit` once on a fresh checkout (locally and in CI) before any `-s` test.
    *   **Prefer path references between scripts** (`extends "res://..."`, `preload("res://...")`) over `class_name` globals, so scripts still resolve if the cache is stale.
    *   **Autoload timing.** When a `SceneTree` script's `_init()` runs, autoloads are not yet in the tree (`EventBus` reads as null). Tests therefore only schedule work in `_init()` and run assertions one frame later (see Section 4).
    *   Always wrap test runs in a timeout (e.g. `timeout 120 godot ...`) so a test that never calls `quit()` cannot hang CI.

---

## 2. Directory Topology & Layer Contracts

### 2.1 File System Topology

```text
chrono_rift/
├── project.godot
├── export_presets.cfg
├── autoload/
│   ├── event_bus.gd
│   └── game_state.gd
├── data/
│   ├── weapons/
│   │   ├── weapon_data.gd           # Core Resource class (class_name WeaponData)
│   │   ├── battle_wrench.tres
│   │   ├── dagger.tres
│   │   └── gladius.tres
│   ├── georama/
│   │   ├── georama_piece_data.gd    # Core Resource class (class_name GeoramaPieceData)
│   │   └── mayor_house.tres
│   └── items/
│       └── item_data.gd
├── scenes/
│   ├── main.tscn                    # Phase 1 test arena: floor, hero, dummies, touch UI
│   ├── characters/
│   │   ├── training_dummy.gd        # Phase 1 lock-on / hitbox target (Layer 3 + Layer 7)
│   │   ├── character_base.gd
│   │   ├── character_base.tscn      # CharacterBody3D + SpringArm3D + Camera3D
│   │   ├── melee_hero.gd            # Combo state machine + persistent Area3D hitbox
│   │   ├── melee_hero.tscn
│   │   ├── ranged_hero.gd
│   │   └── ranged_hero.tscn
│   ├── dungeon/
│   │   ├── dungeon_manager.gd
│   │   ├── dungeon_manager.tscn
│   │   ├── floor_generator.gd       # BSP procedural generation node
│   │   ├── room_node.gd
│   │   ├── atla_sphere.gd
│   │   └── atla_sphere.tscn
│   ├── georama/
│   │   ├── georama_manager.gd
│   │   ├── georama_manager.tscn
│   │   ├── town_grid.gd             # 3D GridMap placement & satisfaction engine
│   │   └── placement_cursor.gd
│   └── ui/
│       ├── virtual_joystick.gd      # Multi-touch deadzone thumbstick
│       ├── virtual_joystick.tscn
│       ├── touch_action_button.gd   # Multi-touch on-screen button mapped to an input action
│       ├── hud_overlay.gd
│       ├── hud_overlay.tscn
│       ├── georama_dock.gd
│       └── georama_dock.tscn
├── scripts/
│   ├── utilities/
│   │   ├── primitive_mesh_factory.gd # Procedural primitive mesh generator
│   │   └── bsp_tree.gd              # Pure data structure for 2D room splitting
│   └── combat/
│       ├── hitbox_3d.gd             # Area3D toggling monitoring during attack frames
│       └── hurtbox_3d.gd            # Area3D receiving damage and notifying owner
└── tests/
    ├── test_harness_template.gd     # Copy this to start a new headless test
    ├── test_phase1_smoke.gd         # Headless test for controllers and physics
    ├── test_bsp_generator.gd        # Headless test for room connectivity and keys
    ├── test_weapon_matrix.gd        # Headless test for durability and build-up
    └── test_georama_rules.gd        # Headless test for satisfaction scoring
```

### 2.2 Collision Layers (3D Physics)

*   Layer 1: `Environment / Geometry` (Solid walls, floors, static obstacles)
*   Layer 2: `Player` (`CharacterBody3D` collision hull)
*   Layer 3: `Enemies` (`CharacterBody3D` collision hull)
*   Layer 4: `Player_Hitbox` (`Area3D` active weapon strike zones)
*   Layer 5: `Player_Hurtbox` (`Area3D` player damage reception zone)
*   Layer 6: `Enemy_Hitbox` (`Area3D` hostile strike zones)
*   Layer 7: `Enemy_Hurtbox` (`Area3D` hostile damage reception zone)
*   Layer 8: `Interactables / Atla` (`Area3D` pickup and trigger detection)

---

## 3. Data Schemas & Core Logic Engines

### 3.1 EventBus Specification (`autoload/event_bus.gd`)

```gdscript
extends Node

# --- Combat & Character ---
signal player_damaged(current_hp: int, max_hp: int)
signal character_swapped(character_id: String)
signal soft_lock_target_changed(target: Node3D)

# --- Inventory & Weapons ---
signal weapon_equipped(weapon_data: Resource)
signal weapon_durability_changed(current: float, max_durability: float, is_broken: bool)
signal weapon_broken(weapon_data: Resource)
signal weapon_built_up(old_weapon: Resource, new_weapon: Resource)

# --- Dungeon & Atla ---
signal atla_collected(atla_id: String, piece_id: String)
signal dungeon_gate_unlocked()
signal floor_cleared()

# --- Georama ---
signal georama_piece_placed(piece_id: String, grid_coord: Vector3i)
signal georama_piece_removed(piece_id: String, grid_coord: Vector3i)
signal georama_satisfaction_updated(piece_id: String, percentage: float)
signal town_restoration_completed()
```

### 3.2 Weapon Data Model & Break Engine (`data/weapons/weapon_data.gd`)

*   **Dark Cloud behaviour (default):** a weapon whose durability (WHP) reaches 0 breaks and is **lost**: the inventory removes it when `weapon_broken` fires and `destroy_on_break` is true. Repair Powder restores WHP before that happens.
*   **Deviation (optional):** `destroy_on_break = false` keeps the broken weapon equipped with a 90% attack penalty until repaired, for an easier mode.
*   Durability is lost when **the weapon lands a hit** (hitbox side), not when the player is hit.

```gdscript
class_name WeaponData
extends Resource

enum ElementType { NONE, FIRE, ICE, THUNDER, WIND, HOLY }
enum SlayerType { NONE, BEAST, UNDEAD, MAGE, SKY, MIMIC, METAL, AQUATIC }

@export var weapon_id: String = ""
@export var display_name: String = "Sturdy Blade"
@export var base_attack: int = 15
@export var current_durability: float = 60.0
@export var max_durability: float = 60.0
@export var is_broken: bool = false
@export var degradation_rate: float = 0.45
## Dark Cloud default: a broken weapon is removed from the inventory.
@export var destroy_on_break: bool = true

@export var elemental_stats: Dictionary = {
	ElementType.FIRE: 0,
	ElementType.ICE: 0,
	ElementType.THUNDER: 0,
	ElementType.WIND: 0,
	ElementType.HOLY: 0
}

@export var slayer_stats: Dictionary = {
	SlayerType.BEAST: 0,
	SlayerType.UNDEAD: 0,
	SlayerType.MAGE: 0,
	SlayerType.SKY: 0,
	SlayerType.MIMIC: 0,
	SlayerType.METAL: 0,
	SlayerType.AQUATIC: 0
}

@export var build_up_branches: Array[Dictionary] = []

func get_effective_attack() -> int:
	if is_broken:
		return maxi(1, int(float(base_attack) * 0.10))
	return base_attack

func apply_degradation(amount: float) -> void:
	if is_broken:
		return
	current_durability = maxf(0.0, current_durability - amount)
	if current_durability <= 0.0:
		is_broken = true
		if is_instance_valid(EventBus):
			EventBus.weapon_broken.emit(self)
	if is_instance_valid(EventBus):
		EventBus.weapon_durability_changed.emit(current_durability, max_durability, is_broken)

func repair(amount: float) -> void:
	current_durability = minf(max_durability, current_durability + amount)
	if current_durability > 0.0:
		is_broken = false
	if is_instance_valid(EventBus):
		EventBus.weapon_durability_changed.emit(current_durability, max_durability, is_broken)

func can_build_up(branch_index: int) -> bool:
	if branch_index < 0 or branch_index >= build_up_branches.size():
		return false
	var req: Dictionary = build_up_branches[branch_index]
	if base_attack < req.get("req_atk", 0):
		return false
	var req_elem: Dictionary = req.get("req_elem", {})
	for el in req_elem.keys():
		if elemental_stats.get(el, 0) < req_elem[el]:
			return false
	return true
```

### 3.3 Procedural Primitive Mesh Factory (`scripts/utilities/primitive_mesh_factory.gd`)

```gdscript
class_name PrimitiveMeshFactory
extends RefCounted

## One material per distinct look, shared by every mesh that uses it.
static var _material_cache: Dictionary = {}

static func get_shared_material(albedo: Color, roughness: float = 0.9, metallic: float = 0.0, emission: Color = Color.BLACK, emission_energy: float = 0.0) -> StandardMaterial3D:
	var key := "%s|%.3f|%.3f|%s|%.3f" % [albedo.to_html(), roughness, metallic, emission.to_html(), emission_energy]
	if _material_cache.has(key):
		return _material_cache[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = albedo
	mat.roughness = roughness
	mat.metallic = metallic
	if albedo.a < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if emission_energy > 0.0:
		mat.emission_enabled = true
		mat.emission = emission
		mat.emission_energy_multiplier = emission_energy
	_material_cache[key] = mat
	return mat

static func create_dungeon_wall_mesh(size: Vector3 = Vector3(2.0, 3.0, 0.4), color: Color = Color(0.2, 0.22, 0.25)) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.material_override = get_shared_material(color, 0.9)
	return mi

static func create_atla_sphere_mesh(color: Color = Color(0.2, 0.8, 1.0, 0.75)) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.45
	sphere.height = 0.9
	mi.mesh = sphere
	mi.material_override = get_shared_material(color, 0.5, 0.0, Color(0.1, 0.4, 0.9), 1.2)
	return mi

static func create_procedural_sword() -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var blade := BoxMesh.new()
	blade.size = Vector3(0.12, 1.1, 0.04)
	mi.mesh = blade
	mi.material_override = get_shared_material(Color(0.75, 0.78, 0.82), 0.2, 0.85)
	return mi
```

Materials are assigned only through `material_override`; meshes carry no material of their own.

---

## 4. Headless Test Harness Structure

Every automated verification script in `tests/` must inherit from `SceneTree` and implement the following structure. `_init()` only schedules the run; assertions start after one frame, once autoloads are in the tree. A watchdog quits with code 1 if a test stalls.

```gdscript
# tests/test_harness_template.gd
extends SceneTree

const TIMEOUT_SECONDS := 60.0

var _failures := 0

func _init() -> void:
	print("--- Running Test Harness ---")
	_run.call_deferred()

func _run() -> void:
	create_timer(TIMEOUT_SECONDS).timeout.connect(_on_timeout)
	await process_frame
	await run_assertions()
	if _failures == 0:
		print("--- Test Passed Successfully ---")
		quit(0)
	else:
		push_error("--- Test Failed (%d failures) ---" % _failures)
		quit(1)

func run_assertions() -> void:
	check(true, "template assertion")

func check(condition: bool, message: String) -> void:
	if condition:
		print("  PASS: " + message)
	else:
		_failures += 1
		push_error("  FAIL: " + message)

func _on_timeout() -> void:
	push_error("--- Test timed out after %.0fs ---" % TIMEOUT_SECONDS)
	quit(1)
```

---

## 5. Phased Execution Prompt Suite

### Phase 1: Engine Baseline, Touch Controls & Melee Combat

```text
Act as an expert Godot 4.3 engine developer building "Chrono Rift", an Android action-RPG inspired by Dark Cloud.

Execute Phase 1 with 100% complete, un-truncated GDScript and .tscn text files matching this topology:
- project.godot (Configured for Android Landscape 1280x720, gl_compatibility, named 3D physics layers 1-8, touch emulation enabled)
- autoload/event_bus.gd (EventBus with signals: player_damaged, weapon_durability_changed, weapon_broken, soft_lock_target_changed)
- autoload/game_state.gd (Tracks active character, thirst gauge, atla inventory, mode enum: DUNGEON / GEORAMA)
- scenes/ui/virtual_joystick.gd + .tscn (Floating multi-touch joystick, deadzone handling; rest position uses a relative viewport anchor Vector2(0.2, 0.7), never absolute pixels)
- scenes/ui/touch_action_button.gd (On-screen multi-touch buttons for attack, dodge and lock-on, anchored to screen corners)
- scenes/characters/character_base.gd + .tscn (CharacterBody3D, gravity, built-in SpringArm3D + Camera3D on Layer 1 mask, Dark Cloud-style lock-on: while the lock-on button is held, the hero faces the nearest enemy in front and strafes around it)
- scenes/characters/melee_hero.gd + .tscn (Inherits base, 3-hit combo state machine, dodgeroll i-frames, persistent Area3D weapon hitbox on Layer 4 toggled active only during attack frames)
- scenes/main.tscn + scenes/characters/training_dummy.gd (Test arena with floor, hero, lock-on/hitbox target dummies and touch UI)
- tests/test_phase1_smoke.gd (Headless test script extending SceneTree, verifying scene loads, joystick vector processing, combo/dodge state machine, and signal registrations, ending with quit(0))

CRITICAL CONSTRAINTS:
1. Wrap all EventBus emissions in safety checks (e.g. `if is_instance_valid(EventBus):`) so scenes run cleanly in isolation during tests.
2. In character_base.gd, use SpringArm3D for the third-person camera. Do not write custom raycast collision rigs.
3. No external binary assets. Generate temporary meshes using BoxMesh/CapsuleMesh directly in code or scene files.
4. In tests/test_phase1_smoke.gd, follow the Section 4 template: schedule from _init(), assert after one frame, call quit(0) on success or quit(1) on failure.
5. Toggle Area3D monitoring with set_deferred("monitoring", value), never by direct assignment from physics callbacks.
6. Reference other scripts by path (extends "res://...", preload) rather than class_name globals.
7. Provide every file completely with zero placeholder comments or omitted logic.
```

### Phase 2: Weapon Degradation, Build-Up & Inventory Engine

```text
Act as an expert Godot 4.3 developer continuing "Chrono Rift". We are implementing the complete Dark Cloud-style weapon progression system.

Generate 100% complete, un-truncated files for:
- data/weapons/weapon_data.gd (Custom resource with class_name WeaponData, 5 Elements, 8 Slayers, current/max durability, degradation rate, destroy_on_break flag (Dark Cloud default: broken weapons are lost), get_effective_attack() with 90% penalty when soft-break is enabled, apply_degradation(), repair(), and can_build_up() branching evaluation)
- data/weapons/battle_wrench.tres (Base starter weapon instance in plain-text Godot resource format)
- data/weapons/gladius.tres (Target evolution weapon instance)
- scripts/combat/hitbox_3d.gd (Area3D subclass, monitoring toggled via set_deferred, damage/slayer payload, applies weapon durability loss when a hit lands)
- scripts/combat/hurtbox_3d.gd (Area3D subclass, damage reception, i-frame timer)
- tests/test_weapon_matrix.gd (Headless test extending SceneTree that instantiates WeaponData, applies degradation to test breaking (destroyed by default, 90% attack penalty with soft-break), repairs, verifies evolution thresholds, and exits with quit(0))

CRITICAL CONSTRAINTS:
1. Store WeaponData at data/weapons/weapon_data.gd.
2. In EventBus signals and script references, preload WeaponData or use duck-typing to prevent circular autoload resolution issues.
3. Provide complete text resource files (.tres) for battle_wrench and gladius.
4. tests/test_weapon_matrix.gd must execute in _init() and exit with quit(0) on success or quit(1) on error.
```

### Phase 3: Procedural BSP Dungeon & Atla Collection Engine

```text
Act as an expert Godot 4.3 developer continuing "Chrono Rift". We are building the procedural dungeon generator and Atla containment loop.

Generate 100% complete, un-truncated files for:
- scripts/utilities/bsp_tree.gd (Pure GDScript recursive binary space partitioning data structure for a 48x48 grid)
- scripts/utilities/primitive_mesh_factory.gd (Procedural mesh creation for walls, floors, doors, and Atla spheres using shared cached materials assigned via material_override)
- scenes/dungeon/floor_generator.gd (Node that takes a BSPTree, carves rooms, builds orthogonal corridors, places Player Spawn at leaf 0, Exit Gate at the furthest leaf, Gate Key on a guarded node, and scatters Atla spheres)
- scenes/dungeon/atla_sphere.gd + .tscn (Area3D on Layer 8, rotating glowing procedural sphere that collects into GameState and emits EventBus.atla_collected)
- tests/test_bsp_generator.gd (Headless test script extending SceneTree that instantiates FloorGenerator, executes 10 generation cycles with unique seeds, verifies 100% path reachability from spawn to key to exit, and exits with quit(0))

CRITICAL CONSTRAINTS:
1. In PrimitiveMeshFactory, share one cached material per look (get_shared_material) and assign it only via mi.material_override.
2. The headless test must be tests/test_bsp_generator.gd extending SceneTree, executing in _init(), and ending with quit(0).
```

### Phase 4: Georama Town Reconstruction & Satisfaction Engine

```text
Act as an expert Godot 4.3 developer continuing "Chrono Rift". We are implementing the Georama town-reconstruction puzzle engine.

Generate 100% complete, un-truncated files for:
- data/georama/georama_piece_data.gd (Resource with class_name GeoramaPieceData, piece_id, structure dimensions Vector2i, culture requirements, array of preference dictionaries)
- data/georama/mayor_house.tres (Complete resource with preferences: proximity to water <= 4 tiles, facing East)
- scenes/georama/town_grid.gd (Grid tracking system managing a 64x64 terrain grid, snapping structures in 90-degree increments, verifying boundaries, and live-evaluating neighbor/feature satisfaction)
- scenes/georama/georama_manager.gd + .tscn (Top-down orthographic camera with touch pan, pinch-zoom, bottom dock UI for selecting unlocked Atla pieces, and placement commit/rollback)
- tests/test_georama_rules.gd (Headless test extending SceneTree that places mayor_house.tres on a mock grid, tests satisfaction calculation under failing vs satisfying conditions, and exits with quit(0))

CRITICAL CONSTRAINTS:
1. Town grid math must be discrete: 1 grid cell = 2.0 x 2.0 Godot World units.
2. Ensure touch input handles pinch-to-zoom and two-finger pan cleanly on Android.
3. tests/test_georama_rules.gd must run in _init() and exit with quit(0) upon passing all assertion checks.
```

### Phase 5: Android Export Preset & Autonomous GitHub Actions CI

```text
Act as an expert Godot 4.3 developer completing "Chrono Rift". We are packaging the project for mobile deployment.

Generate 100% complete files for:
- export_presets.cfg (Production-ready Godot 4 Android export configuration targeting arm64-v8a, landscape orientation, package name com.chronorift.game, Min SDK 24, Target SDK 34)
- .github/workflows/build_android.yml (GitHub Actions workflow that checks out the repo, sets up Godot 4.3-stable headless, initializes editor cache, installs Android SDK/build-tools, runs all tests in tests/, exports the debug and release APK, and uploads them as build artifacts)
- README.md (Setup instructions, touch control guide, and architecture overview)

CRITICAL CONSTRAINTS:
1. Target arm64-v8a as the primary architecture; keep x86_64 commented out or optional.
2. In .github/workflows/build_android.yml, run `godot --headless --path . --editor --quit` prior to testing/exporting to initialize the project cache (if class_name lookups still fail, run it a second time).
4. Wrap every test invocation in `timeout 120` so a hung test fails the job instead of stalling it.
3. The CI pipeline must run tests/test_phase1_smoke.gd, tests/test_bsp_generator.gd, tests/test_weapon_matrix.gd, and tests/test_georama_rules.gd before running the export step. Fail the build if any test returns a non-zero exit code.
```

---

## 6. Autonomous Execution & Verification Protocol

1.  **Step 1:** Submit the Phase 1 Prompt into the coding engine.
2.  **Step 2:** Verify output using the headless test harness:

    ```bash
    godot --headless --path . --editor --quit
    timeout 120 godot --headless --path . -s tests/test_phase1_smoke.gd
    ```

3.  **Step 3:** Commit all verified files to Git once the exit code returns `0`.
4.  **Step 4:** Run subsequent phase prompts in order (Phase 2 through 5) following the same test-and-commit loop.
