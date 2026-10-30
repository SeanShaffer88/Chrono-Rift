extends Node
const Services=preload("res://scripts/utilities/services.gd")
var failures := 0
func _ready() -> void: _run.call_deferred()
func check(value: bool,label: String) -> void:
	if not value: failures+=1
	print("VALIDATION_QA "+("PASS: " if value else "FAIL: ")+label)
func capture(label: String) -> void:
	for frame in 3: await get_tree().process_frame
	print("VALIDATION_QA CAPTURE: "+label)
	await get_tree().create_timer(1.5).timeout
func _run() -> void:
	await get_tree().process_frame
	var dungeon=load("res://scenes/dungeon/dungeon_manager.tscn").instantiate()
	add_child(dungeon)
	var hero=dungeon.get_node("MeleeHero")
	hero.set_physics_process(false)
	check(dungeon.save_session==null,"Isolated QA never loads or replaces shipping autosave")
	check(hero.weapon_inventory.equipped_weapon.weapon_id=="trail_sword","Fresh Infiltrator owns Trail Sword")
	for number in range(1,4):
		Services.game_state().swap_character("melee_hero")
		dungeon.floor_number=number
		dungeon.dungeon_seed=1337
		dungeon._load_floor()
		dungeon.floor_generator.guard.set_physics_process(false)
		for enemy: Node3D in dungeon.floor_generator.encounters.values(): enemy.set_physics_process(false)
		hero.camera_rig.restore_view(0,deg_to_rad(-40))
		await capture("biome-%d-player" % number)
		var corner: Vector2i=dungeon.floor_generator.spawn_cell
		for cell: Vector2i in dungeon.floor_generator.layout.walkable:
			if not dungeon.floor_generator.layout.walkable.has(cell+Vector2i.DOWN) and not dungeon.floor_generator.layout.walkable.has(cell+Vector2i.RIGHT): corner=cell
		hero.position=dungeon.floor_generator.cell_to_world(corner)+Vector3.UP*0.1
		hero.camera_rig.restore_view(0,deg_to_rad(-40))
		check(hero.camera.projection==Camera3D.PROJECTION_ORTHOGONAL and is_equal_approx(hero.camera.size,14.0),"Biome %d corner retains fixed isometric framing" % number)
		await capture("biome-%d-corner" % number)
		var expected: float=hero.camera_rig.get_preferred_yaw()
		var data:=preload("res://scripts/persistence/save_data.gd").actor(hero)
		check(is_equal_approx(data.yaw,expected),"Biome %d save stores intended corner yaw" % number)
		var touch:=InputEventScreenTouch.new()
		touch.index=42
		touch.position=Vector2(1800,360)
		touch.pressed=true
		hero.camera_rig.input(touch)
		var drag:=InputEventScreenDrag.new()
		drag.index=42
		drag.relative=Vector2(80,10)
		hero.camera_rig.input(drag)
		check(is_equal_approx(hero.camera_rig.get_preferred_yaw(),expected),"Biome %d right touch cannot rotate the fixed view" % number)
		touch.pressed=false
		hero.camera_rig.input(touch)
		hero.camera_pivot.rotation.y=hero.camera_rig.get_preferred_yaw()
		hero.camera_rig.distance=hero.camera_distance
		var clear := true
		var probe:=SphereShape3D.new()
		probe.radius=0.23
		var query:=PhysicsShapeQueryParameters3D.new()
		query.shape=probe
		query.collision_mask=1
		for frame in 60:
			hero.camera_rig.update(0.016)
			await get_tree().physics_frame
			var direction: Vector3=(Basis(Vector3.UP,hero.camera_pivot.rotation.y)*Basis(Vector3.RIGHT,hero.spring_arm.rotation.x)).z
			query.transform=Transform3D(Basis.IDENTITY,hero.camera_pivot.global_position+direction*hero.spring_arm.spring_length)
			clear=clear and hero.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty() and hero.spring_arm.rotation.x>=deg_to_rad(-60)-0.001 and hero.spring_arm.rotation.x<=deg_to_rad(-35)+0.001
		check(clear,"Biome %d interpolated camera sphere stays clear with bounded pitch" % number)
		await capture("biome-%d-touch-corner" % number)
		hero._set_lock_target(dungeon.floor_generator.guard)
		for frame in 60:
			hero.camera_rig.update(0.016)
			await get_tree().physics_frame
		check(hero.camera_rig.get_preferred_yaw()!=expected and hero.camera_rig.touch_index==-1,"Biome %d lock tracking and touch release remain active" % number)
		await capture("biome-%d-lock-corner" % number)
		hero._set_lock_target(null)
		hero.position=dungeon.floor_generator.cell_to_world(dungeon.floor_generator.spawn_cell)+Vector3.UP*0.1
		hero.camera_rig.restore_view(0,deg_to_rad(-40))
		await capture("biome-%d-return" % number)
		var camera:=Camera3D.new()
		dungeon.add_child(camera)
		var target: Node3D=dungeon.floor_generator.guard
		if number==2: target=dungeon.floor_generator.content.get_node("DungeonLandmarks/ImportedFrostDetails/valve")
		if number==3: target=dungeon.floor_generator.content.get_node("DungeonLandmarks/DistantRailLandmark/locomotive")
		camera.global_position=target.global_position+(Vector3(7,4,8) if number==3 else Vector3(1.1,0.6,1.6) if number==2 else Vector3(2.6,2.2,4))
		camera.look_at(target.global_position+(Vector3.UP if number!=2 else Vector3.ZERO))
		camera.make_current()
		await capture("biome-%d-detail" % number)
		camera.free()
		hero.camera.make_current()
	for id in ["melee_hero","swordsman","riftwarden"]:
		Services.game_state().swap_character(id)
		await capture("hero-"+id)
	print("VALIDATION_QA COMPLETE failures="+str(failures))
