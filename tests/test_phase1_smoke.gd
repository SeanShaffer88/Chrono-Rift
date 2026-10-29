# tests/test_phase1_smoke.gd
# Phase 1 smoke test: autoload signals, scene loading, joystick math and touch
# handling, melee combo / dodge state machine, damage and gravity.
#   godot --headless --path . -s tests/test_phase1_smoke.gd
extends SceneTree

const TIMEOUT_SECONDS := 60.0
const DT := 1.0 / 60.0

const MAIN_SCENE := "res://scenes/main.tscn"
const HERO_SCENE := "res://scenes/characters/melee_hero.tscn"
const JOYSTICK_SCENE := "res://scenes/ui/virtual_joystick.tscn"
const JoystickScript := preload("res://scenes/ui/virtual_joystick.gd")
const MeleeHeroScript := preload("res://scenes/characters/melee_hero.gd")

var _failures := 0

func _init() -> void:
	print("--- Running Phase 1 Smoke Test ---")
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
	_test_autoloads()
	_test_joystick_math()
	await _test_scene_loads()
	await _test_joystick_touch()
	await _test_melee_combat()
	await _test_gravity()

func check(condition: bool, message: String) -> void:
	if condition:
		print("  PASS: " + message)
	else:
		_failures += 1
		push_error("  FAIL: " + message)

func _on_timeout() -> void:
	push_error("--- Test timed out after %.0fs ---" % TIMEOUT_SECONDS)
	quit(1)

# --- Autoloads ---------------------------------------------------------------

func _test_autoloads() -> void:
	var event_bus := root.get_node_or_null("EventBus")
	var game_state := root.get_node_or_null("GameState")
	check(event_bus != null, "EventBus autoload is in the tree")
	check(game_state != null, "GameState autoload is in the tree")
	if event_bus == null or game_state == null:
		return
	for signal_name in ["player_damaged", "weapon_durability_changed", "weapon_broken", "soft_lock_target_changed", "character_swapped", "atla_collected", "thirst_changed"]:
		check(event_bus.has_signal(signal_name), "EventBus declares signal '%s'" % signal_name)
	game_state.call("reset")
	game_state.call("drain_thirst", 30.0)
	check(is_equal_approx(game_state.get("thirst"), 70.0), "GameState drains thirst")
	game_state.call("refill_thirst")
	check(is_equal_approx(game_state.get("thirst"), 100.0), "GameState refills thirst")
	game_state.call("add_atla", "mayor_house")
	check(game_state.call("has_atla", "mayor_house"), "GameState stores collected Atla")
	game_state.call("reset")

# --- Joystick ----------------------------------------------------------------

func _test_joystick_math() -> void:
	check(JoystickScript.compute_vector(Vector2.ZERO, 100.0, 0.2) == Vector2.ZERO, "joystick: centred stick is zero")
	check(JoystickScript.compute_vector(Vector2(15, 0), 100.0, 0.2) == Vector2.ZERO, "joystick: input inside deadzone is zero")
	check(JoystickScript.compute_vector(Vector2(100, 0), 100.0, 0.2).is_equal_approx(Vector2(1, 0)), "joystick: full deflection is length 1")
	check(JoystickScript.compute_vector(Vector2(0, 250), 100.0, 0.2).is_equal_approx(Vector2(0, 1)), "joystick: over-deflection clamps to length 1")
	check(JoystickScript.compute_vector(Vector2(60, 0), 100.0, 0.2).is_equal_approx(Vector2(0.5, 0)), "joystick: output rescales past the deadzone")

func _test_joystick_touch() -> void:
	var joystick: Control = (load(JOYSTICK_SCENE) as PackedScene).instantiate()
	root.add_child(joystick)
	await process_frame
	var viewport_size := joystick.get_viewport_rect().size
	check(joystick.call("get_rest_position").is_equal_approx(viewport_size * Vector2(0.2, 0.7)), "joystick: rest position is relative to viewport size")

	var start := viewport_size * Vector2(0.15, 0.6)
	joystick._input(_touch(0, start, true))
	check(joystick.call("is_active"), "joystick: touch in the left zone activates the stick")
	joystick._input(_drag(0, start + Vector2(90, 0)))
	check(joystick.call("get_vector").is_equal_approx(Vector2(1, 0)), "joystick: dragging right gives (1, 0)")

	# A second finger on the right side must not steal the stick.
	joystick._input(_touch(1, viewport_size * Vector2(0.9, 0.6), true))
	joystick._input(_drag(1, viewport_size * Vector2(0.9, 0.2)))
	check(joystick.call("get_vector").is_equal_approx(Vector2(1, 0)), "joystick: other fingers are ignored")

	joystick._input(_touch(0, start + Vector2(90, 0), false))
	check(not joystick.call("is_active") and joystick.call("get_vector") == Vector2.ZERO, "joystick: release resets the stick")

	joystick._input(_touch(2, viewport_size * Vector2(0.8, 0.5), true))
	check(not joystick.call("is_active"), "joystick: touches outside the left zone are ignored")
	joystick.queue_free()
	await process_frame

func _touch(index: int, pos: Vector2, pressed: bool) -> InputEventScreenTouch:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = pos
	event.pressed = pressed
	return event

func _drag(index: int, pos: Vector2) -> InputEventScreenDrag:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = pos
	return event

# --- Scenes ------------------------------------------------------------------

func _test_scene_loads() -> void:
	for path in [MAIN_SCENE, HERO_SCENE, JOYSTICK_SCENE]:
		var packed := load(path) as PackedScene
		check(packed != null and packed.can_instantiate(), "scene loads: %s" % path)
	var main: Node = (load(MAIN_SCENE) as PackedScene).instantiate()
	root.add_child(main)
	await physics_frame
	await physics_frame
	check(main.get_node_or_null("MeleeHero") != null, "main scene contains the hero")
	check(main.get_node_or_null("TouchUI/VirtualJoystick") != null, "main scene contains the joystick")
	check(get_nodes_in_group(&"enemies").size() == 2, "main scene registers 2 training dummies as enemies")
	for action in [&"move_left", &"move_right", &"move_forward", &"move_back", &"attack", &"dodge", &"lock_on"]:
		check(InputMap.has_action(action), "input action registered: %s" % action)
	main.queue_free()
	await process_frame

# --- Melee combat ------------------------------------------------------------

func _test_melee_combat() -> void:
	var hero: CharacterBody3D = (load(HERO_SCENE) as PackedScene).instantiate()
	root.add_child(hero)
	await process_frame
	# Freeze the engine's own ticking so only the manual steps below advance combat.
	hero.set_physics_process(false)
	var free_state: int = MeleeHeroScript.CombatState.FREE
	var windup_state: int = MeleeHeroScript.CombatState.WINDUP
	var active_state: int = MeleeHeroScript.CombatState.ACTIVE
	var dodging_state: int = MeleeHeroScript.CombatState.DODGING

	check(hero.get("combat_state") == free_state, "hero starts in FREE state")
	check(hero.get("hitbox_active") == false, "hitbox starts inactive")
	check(hero.get_node("Visual/WeaponPivot/WeaponHitbox").collision_layer == 8, "weapon hitbox is on layer 4 (Player_Hitbox)")
	check(hero.collision_layer == 2, "hero body is on layer 2 (Player)")

	# Single attack: windup -> active (hitbox on) -> recovery -> free.
	var started: Array[int] = []
	hero.connect("attack_started", func(step: int) -> void: started.append(step))
	check(hero.call("request_attack"), "attack request accepted from FREE")
	check(hero.get("combat_state") == windup_state, "attack enters WINDUP")
	check(hero.call("can_move") == false, "hero cannot walk while attacking")
	var saw_active := _advance_until(hero, func() -> bool: return hero.get("combat_state") == active_state, 1.0)
	check(saw_active and hero.get("hitbox_active"), "hitbox is active during ACTIVE frames")
	_advance_until(hero, func() -> bool: return hero.get("combat_state") == free_state, 2.0)
	check(hero.get("combat_state") == free_state and not hero.get("hitbox_active"), "single attack returns to FREE with hitbox off")
	check(str(started) == "[0]", "single press performs one swing")

	# Buffered presses chain the full 3-hit combo, then it ends.
	started.clear()
	hero.call("request_attack")
	for i in 60:
		if i % 6 == 0:
			hero.call("request_attack")
		hero.call("tick_combat", DT)
	_advance_until(hero, func() -> bool: return hero.get("combat_state") == free_state, 3.0)
	check(str(started) == "[0, 1, 2]", "buffered presses chain a 3-hit combo")
	check(hero.get("combo_step") == -1, "combo resets after the third hit")

	# Dodge: i-frames early, vulnerable late, back to FREE.
	check(hero.call("request_dodge"), "dodge accepted from FREE")
	check(hero.get("combat_state") == dodging_state, "dodge enters DODGING")
	check(hero.call("is_invulnerable"), "dodge grants i-frames at start")
	var hp_before: int = hero.get("current_hp")
	check(not hero.call("take_damage", 10) and hero.get("current_hp") == hp_before, "damage is ignored during i-frames")
	_advance(hero, 0.32)
	check(not hero.call("is_invulnerable"), "i-frames end before the dodge does")
	_advance_until(hero, func() -> bool: return hero.get("combat_state") == free_state, 1.0)
	check(hero.get("combat_state") == free_state, "dodge returns to FREE")

	# Damage outside i-frames reaches EventBus.
	var damage_events: Array[int] = []
	var event_bus := root.get_node_or_null("EventBus")
	if event_bus:
		event_bus.connect("player_damaged", func(current: int, _max_hp: int) -> void: damage_events.append(current))
	check(hero.call("take_damage", 10) and hero.get("current_hp") == hp_before - 10, "damage applies outside i-frames")
	check(event_bus == null or str(damage_events) == str([hp_before - 10]), "player_damaged is emitted on EventBus")

	hero.queue_free()
	await process_frame

func _advance(hero: Node, seconds: float) -> void:
	var steps := ceili(seconds / DT)
	for i in steps:
		hero.call("tick_combat", DT)

## Steps combat until the condition holds or the time limit runs out.
func _advance_until(hero: Node, condition: Callable, max_seconds: float) -> bool:
	var elapsed := 0.0
	while elapsed < max_seconds:
		if condition.call():
			return true
		hero.call("tick_combat", DT)
		elapsed += DT
	return condition.call()

# --- Physics -----------------------------------------------------------------

func _test_gravity() -> void:
	var hero: CharacterBody3D = (load(HERO_SCENE) as PackedScene).instantiate()
	root.add_child(hero)
	hero.global_position = Vector3(0, 5, 0)
	for i in 15:
		await physics_frame
	check(hero.global_position.y < 5.0, "hero falls under gravity with no floor")
	hero.queue_free()
	await process_frame
