extends Node
## Isolated Android camera evidence. Never starts shipping persistence.
const Services=preload("res://scripts/utilities/services.gd")
var failures := 0
var assertions := 0
func _ready() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	assertions+=1
	if not ok: failures+=1
	print("CAMERA_QA "+("PASS: " if ok else "FAIL: ")+label)
func capture(label: String) -> void:
	for frame in 3: await get_tree().physics_frame
	print("CAMERA_QA CAPTURE: "+label)
	await get_tree().create_timer(0.8).timeout
func run() -> void:
	var state=Services.game_state()
	state.reset()
	state.record_floor_clear(6)
	var dungeon=load("res://scenes/dungeon/dungeon_manager.tscn").instantiate()
	add_child(dungeon)
	var hero=dungeon.get_node("MeleeHero")
	hero.set_physics_process(false)
	check(dungeon.save_session==null,"Camera QA never loads or writes shipping autosave")
	var sphere := SphereShape3D.new()
	sphere.radius=0.23
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape=sphere
	query.collision_mask=1
	for number in range(1,4):
		dungeon.floor_number=number
		dungeon.dungeon_seed=1337
		dungeon._load_floor()
		dungeon.major_title.cancel()
		dungeon.floor_generator.guard.set_physics_process(false)
		for enemy: Node in dungeon.floor_generator.encounters.values(): enemy.set_physics_process(false)
		var corner: Vector2i=dungeon.floor_generator.spawn_cell
		var nearest := INF
		for cell: Vector2i in dungeon.floor_generator.layout.walkable:
			if dungeon.floor_generator.layout.walkable.has(cell+Vector2i.DOWN) or dungeon.floor_generator.layout.walkable.has(cell+Vector2i.RIGHT): continue
			var distance := Vector2(cell-dungeon.floor_generator.spawn_cell).length_squared()
			if distance<nearest:
				nearest=distance
				corner=cell
		hero.position=dungeon.floor_generator.cell_to_world(corner)+Vector3.UP*0.1
		for id: String in ["melee_hero","swordsman","riftwarden","battlemage","devourer"]:
			state.swap_character(id)
			for pitch: float in [-40.0,-60.0]:
				hero.get_node("Visual").reset_motion()
				hero.camera_rig.restore_view(0,deg_to_rad(pitch))
				for frame in 3: await get_tree().physics_frame
				hero.camera_rig.update(0.016)
				var points: Array[Vector3]=[]
				var profile_ok: bool=hero.get_node("Visual").write_camera_probes(points)
				var view: Dictionary=hero.camera_rig._visibility(hero.camera_pivot.rotation.y,hero.spring_arm.rotation.x,hero.camera.global_position.distance_to(hero.camera_pivot.global_position),profile_ok,hero.camera.global_position)
				query.transform=Transform3D(Basis.IDENTITY,hero.camera.global_position)
				check(profile_ok and view.full and hero.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty(),"Biome%d %s pitch%s actual body rays and camera sphere clear"%[number,id,pitch])
				check(is_zero_approx(hero.camera_rig.get_preferred_yaw()) and hero.spring_arm.rotation.x>=deg_to_rad(-60)-0.001,"Temporary view preserves intended yaw and manual pitch")
				await capture("biome%d-%s-p%d"%[number,id,int(-pitch)])
	state.swap_character("melee_hero")
	hero.camera_rig.restore_view(0,deg_to_rad(-60))
	var durations: Array[int]=[]
	var start_searches: int=hero.camera_rig.searches
	var start_rays: int=hero.camera_rig.body_ray_count
	var budget_ok := true
	for frame in 120:
		hero.camera_rig.orbit(0.0001,0)
		var start := Time.get_ticks_usec()
		hero.camera_rig.update(1.0/60)
		durations.append(Time.get_ticks_usec()-start)
		budget_ok=budget_ok and hero.camera_rig.candidate_count<=8
		await get_tree().physics_frame
	durations.sort()
	print("CAMERA_QA COST emulator_only=true frames=120 p50_us=%d p95_us=%d max_us=%d searches=%d body_rays=%d"%[durations[60],durations[114],durations[-1],hero.camera_rig.searches-start_searches,hero.camera_rig.body_ray_count-start_rays])
	check(budget_ok and hero.camera_rig.searches-start_searches<=21,"Continuous orbit retains bounded ten-Hz candidate searches on Android")
	check(is_equal_approx(hero.camera_rig.get_preferred_yaw(),0.012),"Android manual orbit updates intended yaw")
	await capture("manual-orbit")
	hero._set_lock_target(dungeon.floor_generator.guard)
	for frame in 60:
		hero.camera_rig.update(1.0/60)
		await get_tree().physics_frame
	check(hero.camera_rig.preferred_pitch>=deg_to_rad(-60)-0.001,"Lock-on retains manual pitch")
	await capture("lock-view")
	hero._set_lock_target(null)
	hero.velocity=Vector3(2,0,0)
	hero.get_node("Visual")._process(0.12)
	hero.camera_rig.update(0.016)
	check(hero.camera_rig.body_points.size()==6,"Running pose updates cached node-local probes")
	hero.velocity=Vector3.ZERO
	hero.request_dodge()
	hero.get_node("Visual")._process(0.08)
	hero.camera_rig.update(0.016)
	var ground_safe := true
	for index in 4: ground_safe=ground_safe and hero.camera_rig.body_points[index].y>=hero.global_position.y+0.0199
	check(ground_safe,"Dodge lower probes remain above the floor")
	await capture("dodge-view")
	var intended: float=hero.camera_rig.get_preferred_yaw()
	dungeon.open_town()
	dungeon.town_view.set_editing(false)
	check(dungeon.town_view.get_node("MeleeHero").camera_rig!=null,"Town walking uses the shared camera rig")
	dungeon.close_town()
	check(is_equal_approx(hero.camera_rig.get_preferred_yaw(),intended),"Town return preserves dungeon intended yaw")
	await capture("town-return")
	print("CAMERA_QA COMPLETE failures=%d assertions=%d"%[failures,assertions])
