extends Node
const Services=preload("res://scripts/utilities/services.gd")
const Grid=preload("res://scenes/georama/town_grid.gd")
var failures := 0
var assertions := 0
func _ready() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	assertions+=1
	if not ok: failures+=1
	print("ISO_QA "+("PASS: " if ok else "FAIL: ")+label)
func capture(label: String) -> void:
	for frame in 3: await get_tree().physics_frame
	var ack := "user://isometric-capture-ack"
	if FileAccess.file_exists(ack): DirAccess.remove_absolute(ack)
	print("ISO_QA CAPTURE: "+label)
	if OS.has_feature("android"):
		var deadline := Time.get_ticks_msec()+10000
		while not FileAccess.file_exists(ack) and Time.get_ticks_msec()<deadline: await get_tree().process_frame
		check(FileAccess.file_exists(ack),"Actual screencap acknowledged before leaving "+label)
	else: await get_tree().create_timer(0.9).timeout
func drag(label: String,start: Vector2,end: Vector2) -> void:
	var transform := get_viewport().get_screen_transform()
	start=transform*start
	end=transform*end
	print("ISO_QA DRAG: %s %d %d %d %d 600"%[label,roundi(start.x),roundi(start.y),roundi(end.x),roundi(end.y)])
	await get_tree().create_timer(1.4).timeout
func fixed(hero: Node3D) -> bool:
	return hero.camera.projection==Camera3D.PROJECTION_ORTHOGONAL and is_equal_approx(hero.camera.size,14.0) and is_equal_approx(hero.camera_rig.get_preferred_yaw(),PI/4) and is_equal_approx(hero.spring_arm.rotation.x,deg_to_rad(-55)) and is_equal_approx(hero.spring_arm.spring_length,14.0)
func supported(hero: Node3D) -> bool:
	for owner: Node in hero.camera_rig.wall_bindings:
		if owner.unsupported_count!=0: return false
		for state: Dictionary in owner.bindings:
			var casters := int(state.node.cast_shadow!=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
			if state.has("shadow") and state.shadow.visible: casters+=1
			if casters!=int(state.cast!=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF): return false
	return true
func run() -> void:
	var state=Services.game_state()
	state.reset()
	state.record_floor_clear(6)
	var dungeon=load("res://scenes/dungeon/dungeon_manager.tscn").instantiate()
	add_child(dungeon)
	var hero=dungeon.get_node("MeleeHero")
	hero.set_physics_process(false)
	check(dungeon.save_session==null,"Isolated isometric QA never loads shipping saves")
	for number in range(1,4):
		dungeon.dungeon_seed=1337
		dungeon.floor_number=number
		dungeon._load_floor()
		dungeon.floor_generator.guard.set_physics_process(false)
		for enemy: Node in dungeon.floor_generator.encounters.values(): enemy.set_physics_process(false)
		for room: Rect2i in dungeon.floor_generator.layout.rooms:
			if room.has_point(dungeon.floor_generator.spawn_cell): hero.position=dungeon.floor_generator.cell_to_world(room.get_center())+Vector3.UP*0.1
		hero.camera_rig.snap()
		for frame in 3: await get_tree().physics_frame
		hero.camera_rig.update(0.016)
		check(fixed(hero) and not dungeon.floor_generator.wall_fade.active,"Biome%d open room keeps original materials and fixed framing"%number)
		await capture("biome%d-open"%number)
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
			hero.get_node("Visual").reset_motion()
			hero.camera_rig.restore_view(-1.0,deg_to_rad(-60))
			for frame in 3: await get_tree().physics_frame
			hero.camera_rig.update(0.016)
			check(fixed(hero) and hero.camera_rig.blocked and supported(hero),"Biome%d %s uses localized fade with unchanged caster count/material support"%[number,id])
			await capture("biome%d-%s-corner"%[number,id])
	state.swap_character("melee_hero")
	for room: Rect2i in dungeon.floor_generator.layout.rooms:
		if room.has_point(dungeon.floor_generator.spawn_cell): hero.position=dungeon.floor_generator.cell_to_world(room.get_center())+Vector3.UP*0.1
	hero.camera_rig.snap()
	var basis: Basis=hero.camera.global_basis
	var size: Vector2=get_viewport().get_visible_rect().size
	await drag("camera-no-orbit",size*Vector2(0.7,0.3),size*Vector2(0.8,0.4))
	check(hero.camera.global_basis.is_equal_approx(basis),"Actual Android right-side drag cannot rotate the fixed view")
	var start: Vector3=hero.position
	hero.set_physics_process(true)
	var joystick=dungeon.get_node("TouchUI/VirtualJoystick")
	var rest: Vector2=joystick.get_rest_position()
	await drag("joystick-up-right",rest,rest+Vector2(100,-100))
	hero.set_physics_process(false)
	var delta: Vector3=hero.position-start
	var screen := Vector2(basis.x.dot(delta),-basis.y.dot(delta)).normalized()
	check(delta.length()>0.15 and screen.dot(Vector2(1,-1).normalized())>0.96 and fixed(hero),"Actual Android diagonal joystick movement follows screen direction at fixed framing")
	check(hero.request_dodge(),"Existing dodge remains available")
	hero.tick_combat(0.4)
	check(fixed(hero),"Dodge does not alter the view")
	var times: Array[int]=[]
	var before: int=hero.camera_rig.ray_count
	for frame in 120:
		var began := Time.get_ticks_usec()
		hero.camera_rig.update(1.0/60)
		times.append(Time.get_ticks_usec()-began)
		await get_tree().physics_frame
	times.sort()
	print("ISO_QA COST emulator_only=true p50_us=%d p95_us=%d max_us=%d rays=%d frames=120"%[times[60],times[114],times[-1],hero.camera_rig.ray_count-before])
	check(hero.camera_rig.ray_count-before<=720,"Fixed camera uses at most six cached body rays per frame and no yaw searches")
	for part: String in Grid.PARTS: state.collect_restoration_orb("qa_"+part,part)
	var grid := Grid.new()
	grid.bind_session(state)
	for id: String in state.town_objects:
		var record: Dictionary=state.town_objects[id]
		for slot: String in grid.catalog[record.piece_id].slots:
			if record.piece_id=="mayor_house" and slot in ["Stove","Resident"]: continue
			grid.assemble(id,slot,"qa_"+grid.catalog[record.piece_id].slots[slot])
	grid.place("qa_mayor_house",Vector2i(28,30),1)
	grid.place("qa_cottage",Vector2i(34,30),0)
	dungeon.open_town()
	var town=dungeon.town_view
	check(town.editing and not town.get_node("MeleeHero").camera_rig.active,"Georama retains overhead editing and disables gameplay wall fade")
	await capture("town-edit")
	town.set_editing(false)
	town.set_process(false)
	var walker=town.get_node("MeleeHero")
	walker.set_physics_process(false)
	var model: Node3D=town._models["qa_mayor_house"]
	for id: String in ["melee_hero","swordsman","riftwarden","battlemage","devourer"]:
		state.swap_character(id)
		walker.position=model.to_global(Vector3(0,0.1,-2.3))
		town._process(0.01)
		walker.set_physics_process(false)
		walker.camera_rig.snap()
		for frame in 3: await get_tree().physics_frame
		walker.camera_rig.update(0.016)
		check(fixed(walker) and supported(walker) and not model.get_node("Roof").visible,"Town %s keeps fixed view, original shadow count and existing inside-roof hide"%id)
		await capture("town-%s-interior"%id)
	town.set_editing(true)
	town._process(0.01)
	check(model.get_node("Roof").visible and not walker.camera_rig.active,"Town edit restores roof and relinquishes the gameplay fade owner")
	dungeon.close_town()
	check(fixed(hero) and hero.camera_rig.active,"Dungeon return restores its fixed gameplay camera")
	await capture("dungeon-return")
	print("ISO_QA COMPLETE failures=%d assertions=%d"%[failures,assertions])
