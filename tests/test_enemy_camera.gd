extends "res://tests/test_harness_template.gd"
const Floor = preload("res://scenes/dungeon/floor_generator.gd")
const Enemy = preload("res://scenes/characters/dungeon_guard.gd")
const Services = preload("res://scripts/utilities/services.gd")
var factory: Node3D

func new_guard(at: Vector3) -> CharacterBody3D:
	var guard: CharacterBody3D = factory._create_guard()
	guard.floor_owner = null
	guard.position = at
	root.add_child(guard)
	guard.set_physics_process(false)
	return guard

func wall(at: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = at
	body.collision_layer = 1
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	root.add_child(body)
	return body

func run_assertions() -> void:
	Services.game_state().reset()
	factory = Floor.new()
	root.add_child(factory)
	factory.generate(1337, 1, false)
	var hero = load("res://scenes/characters/melee_hero.tscn").instantiate()
	hero.position = Vector3(0, 0, -1.3)
	root.add_child(hero)
	hero.set_physics_process(false)
	var guard = new_guard(Vector3.ZERO)
	await physics_frame
	await physics_frame
	guard.tick_brain(0.01)
	var health_events: Array[Vector2i] = []
	hero.hp_changed.connect(func(current: int, maximum: int): health_events.append(Vector2i(current, maximum)))
	check(guard.state == Enemy.State.WINDUP and guard.warning.visible, "Nearby player triggers visible attack windup")
	check(hero.current_hp == 100 and not guard.attack_box.active, "Windup cannot deal damage")
	guard.tick_brain(Enemy.WINDUP_TIME)
	check(guard.state == Enemy.State.ACTIVE and not guard.warning.visible, "Windup ends before attack becomes active")
	for i in 4: await physics_frame
	check(hero.current_hp == 88, "Actual enemy Area overlap deals one acknowledged hit")
	check(health_events == [Vector2i(88, 100)], "Enemy hit emits exactly one health signal with current/max payload")
	check(not guard.try_attack_hit(hero.get_node("Hurtbox")) and hero.current_hp == 88, "Active window cannot double-hit a player")
	guard.tick_brain(Enemy.ACTIVE_TIME)
	check(guard.state == Enemy.State.RECOVERY and not guard.attack_box.active, "Active damage stops on recovery")
	guard.tick_brain(Enemy.RECOVERY_TIME)
	check(guard.state == Enemy.State.PURSUIT, "Recovery returns to pursuit")
	guard._set_state(Enemy.State.WINDUP)
	guard.receive_hit(1, hero)
	check(guard.state == Enemy.State.STAGGER and not guard.warning.visible and not guard.attack_box.active, "Stagger interrupts windup and removes warning/damage")
	guard.tick_brain(Enemy.STAGGER_TIME)
	check(guard.state == Enemy.State.PURSUIT, "Stagger has a bounded recovery")
	hero._dodge_cooldown_left = 0.0
	check(hero.request_dodge(), "Player can dodge before enemy swing")
	guard._set_state(Enemy.State.ACTIVE)
	check(not guard.try_attack_hit(hero.get_node("Hurtbox")) and hero.current_hp == 88, "Dodge i-frames reject enemy damage")
	hero.tick_combat(0.3)
	check(guard.try_attack_hit(hero.get_node("Hurtbox")), "Rejected hit may retry after i-frames end")
	check(not guard.try_attack_hit(hero.get_node("Hurtbox")), "Accepted retry is still limited to one hit")
	hero.tick_combat(0.2)
	var barrier := wall(Vector3(0, 1, -0.65), Vector3(3, 3, 0.15))
	await physics_frame
	await physics_frame
	guard._set_state(Enemy.State.ACTIVE)
	var hp: int = hero.current_hp
	check(not guard.try_attack_hit(hero.get_node("Hurtbox")) and hero.current_hp == hp, "Environment blocks enemy damage")
	hero._on_weapon_equipped(hero.weapon_inventory.equipped_weapon)
	hero.face_direction(Vector3.BACK)
	hero.request_attack()
	hero.tick_combat(0.11)
	var whp: float = hero.weapon_inventory.equipped_weapon.current_durability
	var enemy_hp: int = guard.current_hp
	hero._on_weapon_hitbox_area_entered(guard.get_node("Hurtbox"))
	check(guard.current_hp == enemy_hp and hero.weapon_inventory.equipped_weapon.current_durability == whp, "Blocked player swing cannot deal damage or consume durability")
	barrier.free()
	await physics_frame
	hero._on_weapon_hitbox_area_entered(guard.get_node("Hurtbox"))
	check(guard.current_hp == enemy_hp - 15 and hero.weapon_inventory.equipped_weapon.current_durability < whp, "Clear swing deals damage, wears weapon and staggers guard")
	guard._set_state(Enemy.State.ACTIVE)
	guard.receive_hit(999, hero)
	check(guard.state == Enemy.State.DEAD and not guard.attack_box.active and not guard.warning.visible, "Lethal hit immediately cancels attack and warning")
	hp = hero.current_hp
	guard._on_attack_entered(hero.get_node("Hurtbox"))
	guard.tick_brain(10.0)
	check(hero.current_hp == hp and guard.attack_contacts.is_empty(), "Late overlap and timers cannot resurrect a dead attack")
	guard.free()
	hero._on_weapon_equipped(hero.weapon_inventory.equipped_weapon)
	hero.position = Vector3.ZERO
	hero.face_direction(Vector3.FORWARD)
	var first = new_guard(Vector3(0, 0, -3))
	var second = new_guard(Vector3(3, 0, -3))
	hero.force_lock_on = true
	var target_events: Array = []
	Services.event_bus().soft_lock_target_changed.connect(func(value): target_events.append(value))
	hero.update_lock_on()
	check(hero.lock_target == first and target_events.size() == 1 and target_events[0] == first, "Lock selects nearest visible enemy and emits exact target")
	hero.update_lock_on()
	check(target_events.size() == 1, "Unchanged lock does not emit duplicate notifications")
	check(hero.cycle_lock_target() and hero.lock_target == second, "Next-target input cycles deterministically")
	second.receive_hit(999, hero)
	hero.update_lock_on()
	check(hero.lock_target == first, "Dead target releases and another visible enemy is acquired")
	barrier = wall(Vector3(0, 1, -1.5), Vector3(6, 3, 0.15))
	await physics_frame
	await physics_frame
	hero.update_lock_on()
	check(hero.lock_target == null and target_events.back() == null, "Wall occlusion releases target and emits null")
	barrier.free()
	await physics_frame
	hero.update_lock_on()
	first.position.z = -20
	hero.update_lock_on()
	check(hero.lock_target == null, "Out-of-range target is released")
	first.position.z = -3
	hero.update_lock_on()
	hero.force_lock_on = false
	hero.update_lock_on()
	check(hero.lock_target == null and not hero.cycle_lock_target(), "Releasing lock ends targeting and disables cycling")
	first.free()
	second.free()
	guard = new_guard(Vector3(5, 0, 0))
	guard.patrol_points.clear()
	guard.patrol_points.append(Vector3(7, 0, 0))
	barrier = wall(Vector3(2.5, 1, 0), Vector3(0.2, 3, 6))
	await physics_frame
	await physics_frame
	guard.tick_brain(0.01)
	check(guard.state == Enemy.State.PATROL and guard.target == null and guard.velocity.x > 0, "Unaware enemy patrols and cannot see through walls")
	barrier.free()
	await physics_frame
	guard.sense_left = 0.0
	guard.tick_brain(0.01)
	check(guard.state == Enemy.State.PURSUIT and guard.velocity.x < 0, "Enemy awareness starts pursuit toward player")
	hero.position.x = 30
	guard.tick_brain(0.2)
	check(guard.target == null and guard.state == Enemy.State.PATROL, "Leash returns enemy to patrol")
	guard.free()
	var start: Vector3 = factory.cell_to_world(factory.spawn_cell)
	var route: Array[Vector3] = factory.find_guard_path(start, factory.cell_to_world(factory.key_cell))
	check(not route.is_empty() and route.back() == factory.cell_to_world(factory.key_cell), "Guard navigation reaches goal through generated layout")
	var previous := Vector2i(roundi(start.x / 2), roundi(start.z / 2))
	var valid_route := true
	for point in route:
		var cell := Vector2i(roundi(point.x / 2), roundi(point.z / 2))
		valid_route = valid_route and factory.layout.walkable.has(cell) and abs(cell.x - previous.x) + abs(cell.y - previous.y) == 1
		previous = cell
	check(valid_route, "Navigation only uses adjacent walkable tiles")
	check(factory.find_guard_path(start, Vector3(-100, 0, -100)).is_empty(), "Invalid navigation destination is rejected")
	hero.position = Vector3.ZERO
	hero.camera_pivot.rotation.y = 0
	var focus := Node3D.new()
	focus.position = Vector3(0, 0, -3)
	root.add_child(focus)
	hero._set_lock_target(focus)
	hero.camera_rig.snap()
	check(hero.camera_pivot.global_position.x > 0.5, "Lock camera offsets shoulder to keep enemy readable")
	hero.camera_rig.orbit(0.5, 0.0)
	var manual_yaw: float = hero.camera_pivot.rotation.y
	hero.camera_rig.update(0.1)
	check(is_equal_approx(hero.camera_pivot.rotation.y, manual_yaw), "Manual orbit takes priority over lock camera tracking")
	hero._set_lock_target(null)
	focus.free()
	hero.camera_pivot.rotation.y = 0
	hero.camera_rig.snap()
	check(hero.spring_arm.shape is SphereShape3D and hero.camera.near <= 0.1, "Camera uses collision volume and short near plane")
	barrier = wall(Vector3(0, 2, 3), Vector3(12, 8, 0.2))
	await physics_frame
	await physics_frame
	hero.camera_rig.update(0.016)
	var shortened: float = hero.spring_arm.spring_length
	check(shortened < 3.5 and shortened > 0.0, "Camera retracts immediately before obstruction")
	for i in 3: await physics_frame
	check(hero.camera.global_position.z < 2.9, "Native spring arm keeps actual camera in front of wall")
	barrier.free()
	await physics_frame
	hero.camera_rig.update(0.016)
	check(hero.spring_arm.spring_length > shortened and hero.spring_arm.spring_length < hero.camera_distance, "Camera eases outward after obstruction clears")
	for i in 150: hero.camera_rig.update(0.016)
	check(absf(hero.spring_arm.spring_length - hero.camera_distance) < 0.01, "Camera returns to desired distance")
	hero.camera_rig.orbit(0.1, 100.0)
	check(is_equal_approx(hero.spring_arm.rotation.x, deg_to_rad(-12)), "Camera tilt clamps at upper limit")
	hero.camera_rig.orbit(0.0, -100.0)
	check(is_equal_approx(hero.spring_arm.rotation.x, deg_to_rad(-55)), "Camera tilt clamps at lower limit")
	hero.camera_rig.orbit(0.0, deg_to_rad(27))
	barrier = wall(Vector3(0, 1.4, 1.0), Vector3(8, 2.8, 0.2))
	await physics_frame
	await physics_frame
	hero.camera_rig.snap()
	check(hero.spring_arm.rotation.x < deg_to_rad(-55) and hero.spring_arm.spring_length > 3.0, "Very close low wall raises camera to keep combat visible")
	barrier.free()
	await physics_frame
	for i in 150: hero.camera_rig.update(0.016)
	check(absf(hero.spring_arm.rotation.x - hero.camera_rig.preferred_pitch) < 0.01, "Automatic camera rescue restores player's preferred tilt")
	hero.camera_rig.touch_index = 7
	hero._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(hero.camera_rig.touch_index == -1, "Focus loss releases camera gesture ownership")
	hero.camera_rig.touch_index = 7
	hero._notification(Node.NOTIFICATION_PAUSED)
	check(hero.camera_rig.touch_index == -1, "Pause menus release camera gesture ownership")
	var yaw_before: float = hero.camera_pivot.rotation.y
	Input.action_press("camera_right")
	hero._physics_process(0.016)
	Input.action_release("camera_right")
	check(hero.camera_pivot.rotation.y < yaw_before, "Keyboard camera action rotates the live controller")
	var touch := InputEventScreenTouch.new()
	touch.index = 9
	touch.pressed = true
	touch.position = Vector2(1000, 250)
	hero.camera_rig.input(touch)
	var drag := InputEventScreenDrag.new()
	drag.index = 9
	drag.relative = Vector2(50, -20)
	yaw_before = hero.camera_pivot.rotation.y
	hero.camera_rig.input(drag)
	check(hero.camera_pivot.rotation.y < yaw_before, "Right-side drag rotates camera")
	touch.canceled = true
	hero.camera_rig.input(touch)
	check(hero.camera_rig.touch_index == -1, "Canceled touch releases camera gesture")
	hero.position = Vector3(40, 0, 40)
	hero.camera_rig.snap()
	check(hero.camera_pivot.global_position.distance_to(hero.position + Vector3.UP * hero.camera_height) < 0.01, "Floor teleport explicitly snaps camera anchor")
	hero.free()
	factory.free()
	await _test_retry()
	Services.game_state().reset()

func _test_retry() -> void:
	var dungeon = load("res://scenes/dungeon/dungeon_manager.tscn").instantiate()
	root.add_child(dungeon)
	var state := Services.game_state()
	state.collect_restoration_orb("retry:part", "tree")
	var weapon = state.weapon_inventory.equipped_weapon
	weapon.apply_degradation(3.0)
	var wear: float = weapon.current_durability
	var seed_value: int = dungeon.floor_generator.floor_seed
	check(not dungeon.retry_floor(), "Living player cannot farm retry resets")
	dungeon.get_node("MeleeHero").take_damage(999)
	check(dungeon.get_node("TouchUI/DefeatPanel").visible, "Defeat presents retry control")
	check(dungeon.retry_floor(), "Defeated player can retry")
	check(dungeon.get_node("MeleeHero").current_hp == 100 and dungeon.floor_generator.floor_seed == seed_value and dungeon.floor_number == 1, "Retry restores HP on the same seeded floor")
	check(state.has_collected_orb("retry:part") and weapon.current_durability == wear, "Retry preserves collected parts and weapon wear")
	check(not dungeon.get_node("TouchUI/DefeatPanel").visible and not dungeon.floor_generator.guard_defeated, "Retry hides defeat UI and resets enemy encounter")
	dungeon.open_town()
	dungeon.town_view.set_editing(false)
	dungeon.town_view._joystick._set_value(Vector2(0.5, 0))
	check(dungeon.town_view.get_node("MeleeHero").get_move_input() == Vector2(0.5, 0), "Walking camera/controller reads town joystick instead of hidden dungeon input")
	dungeon.close_town()
	dungeon.free()
	await process_frame
