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
	_test_body_profiles(hero)
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
	check(not guard.try_attack_hit(null), "Enemy damage rejects a missing hurtbox")
	var stale := Area3D.new()
	root.add_child(stale)
	guard.attack_contacts[stale.get_instance_id()] = stale
	stale.free()
	guard.tick_brain(0.01)
	check(hero.current_hp == 88, "Freed overlap receiver is skipped safely during active attack")
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
	await _test_fixed_camera(hero)
	await _test_town_camera(hero)
	hero.free()
	factory.free()
	await _test_retry()
	Services.game_state().reset()

func _test_body_profiles(hero: Node3D) -> void:
	var visual: Node3D=hero.get_node("Visual")
	visual.set_process(false)
	var out: Array[Vector3]=[]
	var stable_count := visual.get_child_count()
	for id: String in ["melee_hero","swordsman","riftwarden","battlemage","devourer"]:
		visual.apply_character(id)
		var valid: bool=visual.write_camera_probes(out) and out.size()==6
		for point in out: valid=valid and point.is_finite()
		check(valid,"%s provides six finite cached body probes"%id)
		var first := out.duplicate()
		var profile: RefCounted=visual.camera_profile
		var attached: Node3D=profile.nodes[0]
		var original := attached.transform
		attached.position.x+=0.1
		visual.write_camera_probes(out)
		check(out[0].distance_to(first[0])>0.09,"%s probes follow their cached art node rather than frozen world positions"%id)
		attached.transform=original
		visual.rotation.y=0.7
		visual.write_camera_probes(out)
		check(out[0].distance_to(first[0])>0.05,"%s probes transform with current Visual orientation"%id)
		visual.rotation.y=0
		if id=="devourer":
			var shell: MeshInstance3D=visual.get_node("DevourerArt/Shell")
			var lower_ok := true
			for index in 4:
				var local: Vector3=shell.global_transform.affine_inverse()*out[index]
				lower_ok=lower_ok and absf(local.y+0.30/shell.scale.y)<0.0001 and Vector2(local.x,local.z).length()<0.5
			check(lower_ok,"Devourer lower probes come from its actual shell slice inside the spherical envelope")
		else:
			visual._apply_pose(preload("res://scripts/utilities/character_motion.gd").sample(6,1.2,0,0,1,0,false,{}))
			visual.write_camera_probes(out)
			check(out[0].distance_to(first[0])>0.01,"%s running legs update the cached lower-body envelope"%id)
		visual.reset_motion()
		visual.apply_character(id)
		check(visual.camera_profile==profile and visual.get_child_count()==stable_count,"%s swaps reuse the profile without accumulating art nodes"%id)
	visual.apply_character("melee_hero")
	visual.set_process(true)

func _test_fixed_camera(hero: Node3D) -> void:
	hero.position=Vector3.ZERO
	hero.camera_rig.restore_view(0.63,deg_to_rad(-60))
	check(hero.camera.projection==Camera3D.PROJECTION_ORTHOGONAL and hero.camera.keep_aspect==Camera3D.KEEP_HEIGHT and is_equal_approx(hero.camera.size,14.0),"Gameplay uses fixed orthographic KEEP_HEIGHT framing at size14")
	check(is_equal_approx(hero.camera_rig.get_preferred_yaw(),PI/4) and is_equal_approx(hero.camera_rig.preferred_pitch,deg_to_rad(-55)),"Version4 camera values load into the fixed45/-55 view")
	for magnitude: float in [0.35,1.0]:
		for direction: Vector2 in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN,Vector2(-1,-1).normalized(),Vector2(1,-1).normalized(),Vector2(-1,1).normalized(),Vector2(1,1).normalized()]:
			var input_value := direction*magnitude
			var world: Vector3=hero.get_camera_relative_direction(input_value)
			var projected := Vector2(hero.camera.global_basis.x.dot(world),-hero.camera.global_basis.y.dot(world)).normalized()
			check(projected.dot(direction)>0.9999 and absf(world.length()-magnitude)<0.0001,"Inverse ground projection preserves screen direction and analog speed %s/%s"%[direction,magnitude])
	var fixed_basis: Basis=hero.camera.global_basis
	var focus := Node3D.new()
	focus.position=Vector3(0,0,-3)
	root.add_child(focus)
	hero._set_lock_target(focus)
	for frame in 60: hero.camera_rig.update(1.0/60)
	check(hero.camera.global_basis.is_equal_approx(fixed_basis),"Combat lock-on does not rotate the gameplay view")
	hero._set_lock_target(null)
	focus.free()
	hero.camera_rig.orbit(2.0,-2.0)
	Input.action_press("camera_right")
	hero._physics_process(0.016)
	Input.action_release("camera_right")
	var touch := InputEventScreenTouch.new()
	touch.index=9
	touch.pressed=true
	touch.position=Vector2(1000,250)
	hero.camera_rig.input(touch)
	var drag := InputEventScreenDrag.new()
	drag.index=9
	drag.relative=Vector2(100,-80)
	hero.camera_rig.input(drag)
	check(hero.camera.global_basis.is_equal_approx(fixed_basis) and hero.camera_rig.touch_index==-1,"Orbit API, keyboard and drag cannot change the fixed view or capture a camera gesture")
	hero.position=Vector3.ZERO
	hero.camera_rig.snap()
	var barrier := wall(Vector3(0,1.4,1),Vector3(8,2.8,0.2))
	var mesh: MeshInstance3D=preload("res://scripts/utilities/primitive_mesh_factory.gd").create_box(Vector3(8,2.8,0.2),Color("526873"))
	barrier.add_child(mesh)
	var original: Material=mesh.material_override
	var caster: int=mesh.cast_shadow
	var roots: Array[Node]=[mesh]
	var binding: Node=preload("res://scripts/utilities/wall_fade_bindings.gd").create(barrier,roots)
	var bindings: Array[Node]=[binding]
	hero.camera_rig.set_wall_bindings(bindings)
	await physics_frame
	await physics_frame
	hero.camera_rig.update(0.016)
	check(binding.active and hero.camera_rig.blocked and hero.camera.global_basis.is_equal_approx(fixed_basis) and is_equal_approx(hero.spring_arm.spring_length,14.0),"Blocking wall activates localized fade without rotating or retracting the camera")
	var proxy: GeometryInstance3D=mesh.get_node("OriginalWallShadow")
	check(mesh.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF and proxy.visible and proxy.mesh==mesh.mesh and proxy.material_override==original,"Active wall variant uses one original-resource shadow-only proxy")
	check(proxy.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY and binding.unsupported_count==0,"Active caster count remains one and the actual material is supported")
	var count := mesh.get_child_count()
	for frame in 120: binding.set_active(frame%2==0)
	check(mesh.get_child_count()==count and binding.variants.size()==1,"Repeated fade transitions neither clone resources nor accumulate shadow nodes")
	barrier.position.z=50
	await physics_frame
	hero.camera_rig.update(0.016)
	check(not binding.active and mesh.material_override==original and mesh.cast_shadow==caster and not proxy.visible,"Clear view restores exact original material/caster and hides the cached proxy")
	binding.clear()
	check(binding.bindings.is_empty() and binding.variants.is_empty() and not mesh.has_node("OriginalWallShadow"),"Owner clear frees variant/proxy caches and leaves original art intact")
	hero.camera_rig.set_wall_bindings([])
	barrier.free()
	await physics_frame
	var points: Array[Vector3]=[]
	hero.get_node("Visual").write_camera_probes(points)
	var target := points[4]
	var blocker := wall(target+hero.camera.global_basis.z*3.5,Vector3(0.035,0.035,0.035))
	var blocker_mesh: MeshInstance3D=preload("res://scripts/utilities/primitive_mesh_factory.gd").create_box(Vector3(0.035,0.035,0.035),Color.WHITE)
	blocker.add_child(blocker_mesh)
	var blocker_roots: Array[Node]=[blocker_mesh]
	var blocker_binding: Node=preload("res://scripts/utilities/wall_fade_bindings.gd").create(blocker,blocker_roots)
	hero.camera_rig.set_wall_bindings([blocker_binding])
	await physics_frame
	var center_query := PhysicsRayQueryParameters3D.create(hero.camera.global_position,target,1)
	var parallel_query := PhysicsRayQueryParameters3D.create(hero.camera.project_ray_origin(hero.camera.unproject_position(target)),target,1)
	hero.camera_rig.update(0.016)
	check(hero.get_world_3d().direct_space_state.intersect_ray(center_query).is_empty() and not hero.get_world_3d().direct_space_state.intersect_ray(parallel_query).is_empty() and hero.camera_rig.blocked,"Off-center orthographic blocker is detected by the rendered pixel's parallel ray, not a central perspective ray")
	hero.camera_rig.set_wall_bindings([])
	blocker.free()
	var before: Vector3=hero.camera_pivot.global_position
	hero.position+=Vector3(1,0,1)
	hero.camera_rig.update(0.016)
	check(hero.camera_pivot.global_position.distance_to(before)>0 and hero.camera_pivot.global_position.distance_to(hero.position+Vector3.UP*hero.camera_height)>0,"Fixed camera follows smoothly without changing its framing")
	hero.position=Vector3(40,0,40)
	hero.camera_rig.snap()
	check(hero.camera_pivot.global_position.distance_to(hero.position+Vector3.UP*hero.camera_height)<0.001 and hero.camera.global_basis.is_equal_approx(fixed_basis),"Teleport snaps the follow anchor without changing isometric angle")
	var record := preload("res://scripts/persistence/save_data.gd").actor(hero)
	check(preload("res://scripts/persistence/save_data.gd").valid_actor(record) and is_equal_approx(float(record.yaw),PI/4),"Fixed view persists in the existing strict version4 actor fields")
	var viewport := SubViewport.new()
	root.add_child(viewport)
	var other := Camera3D.new()
	viewport.add_child(other)
	other.make_current()
	var visibility=preload("res://scripts/utilities/wall_visibility.gd")
	visibility.publish(other,hero,hero.camera_rig.SETTINGS,true)
	hero.camera_rig.set_active(false)
	check(visibility.owner!=null and visibility.owner.get_ref()==other,"Old camera release cannot clear a newer viewport camera's fade ownership")
	visibility.release(other)
	viewport.free()
	hero.camera_rig.set_active(true)

func _test_town_camera(hero: Node3D) -> void:
	var house: Node3D=preload("res://scenes/georama/town_visuals.gd").make(load("res://data/georama/mayor_house.tres"),{"components":{"Roof":"roof","Door":"door"}})
	house.position=Vector3(50,0,50)
	root.add_child(house)
	house.get_node("Door/Collision").disabled=true
	await physics_frame
	for local: Vector3 in [Vector3(0,0.1,-3.4),Vector3(0,0.1,-2.3),Vector3(2.1,0.1,2.1)]:
		hero.position=house.to_global(local)
		hero.camera_rig.restore_view(0.4,deg_to_rad(-60))
		hero.camera_rig.orbit(0.2,0)
		check(is_equal_approx(hero.camera_rig.get_preferred_yaw(),PI/4) and is_equal_approx(hero.camera_rig.preferred_pitch,deg_to_rad(-55)) and hero.camera.projection==Camera3D.PROJECTION_ORTHOGONAL,"Town doorway/interior walking retains the same fixed isometric pose %s"%local)
	house.free()

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
