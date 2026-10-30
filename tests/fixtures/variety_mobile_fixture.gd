extends Node
const Decor=preload("res://scenes/environment/dungeon_landmarks.gd")
var failures := 0
func _ready() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	if not ok: failures+=1
	print("VARIETY_QA "+("PASS: " if ok else "FAIL: ")+label)
func capture(label: String) -> void:
	for frame in 3: await get_tree().physics_frame
	var ack := "user://variety-capture-ack"
	if FileAccess.file_exists(ack): DirAccess.remove_absolute(ack)
	print("VARIETY_QA CAPTURE: "+label)
	var deadline := Time.get_ticks_msec()+15000
	while not FileAccess.file_exists(ack) and Time.get_ticks_msec()<deadline: await get_tree().process_frame
	check(FileAccess.file_exists(ack),"Actual capture acknowledged: "+label)
func run() -> void:
	var state=get_node("/root/GameState")
	state.reset()
	var dungeon=load("res://scenes/dungeon/dungeon_manager.tscn").instantiate()
	add_child(dungeon)
	check(dungeon.save_session==null,"Isolated QA does not load shipping saves")
	var hero=dungeon.get_node("MeleeHero")
	hero.set_physics_process(false)
	for number in range(1,4):
		dungeon.dungeon_seed=9271
		dungeon.floor_number=number
		dungeon._load_floor()
		var floor_node=dungeon.floor_generator
		var original=Decor.plan(floor_node.layout.rooms,floor_node.layout.walkable,floor_node.floor_seed)
		check(original.size()<=8,"Biome %d decoration budget"%number)
		check(original!=Decor.plan(floor_node.layout.rooms,floor_node.layout.walkable,floor_node.floor_seed+1),"Biome %d independent arrangement changes with seed"%number)
		for room: Rect2i in floor_node.layout.rooms:
			if room.has_point(floor_node.spawn_cell): hero.position=floor_node.cell_to_world(room.get_center())+Vector3.UP*.1
		hero.camera_rig.snap()
		await capture("biome%d-arrangement"%number)
		var walkable: Array=floor_node.layout.walkable.keys()
		dungeon._load_floor()
		check(walkable==dungeon.floor_generator.layout.walkable.keys() and dungeon.dungeon_seed==9271,"Biome %d retry preserves exact expedition"%number)
	dungeon.open_town()
	await get_tree().process_frame
	var town=dungeon.town_view
	var camera: Camera3D=town.get_node("CameraPivot/Camera3D")
	check(camera.size==14.0 and is_equal_approx(camera.rotation.x,deg_to_rad(-55.0)),"Actual Android editor default framing")
	town.orbit(25)
	town.tilt(5)
	camera.size=18.0
	var pose:=camera.global_transform
	town._refresh()
	town._layout_ui()
	check(camera.global_transform.is_equal_approx(pose) and camera.size==18.0,"Android editor controls survive refresh")
	camera.size=110.0
	town._pitch=25.0
	town._update_camera()
	check(camera.project_ray_origin(Vector2(0,get_viewport().get_visible_rect().size.y)).y>0.0,"Android maximum zoom near plane stays above terrain")
	camera.size=18.0
	town._pitch=60.0
	town._update_camera()
	var point:=Vector3(65,0,68)
	var projected: Variant=town.ground_point(camera.unproject_position(point))
	check(projected is Vector3 and projected.distance_to(point)<.001,"Android placement projection roundtrip")
	town.set_editing(false)
	town.set_editing(true)
	check(camera.size==14.0,"Android re-entry resets only editor default")
	await capture("editor-default-with-controls")
	print("VARIETY_QA COMPLETE failures="+str(failures))
