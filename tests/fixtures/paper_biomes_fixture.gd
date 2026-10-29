extends SceneTree
var viewport: SubViewport
var output := ""
func _init() -> void: _run.call_deferred()
func capture(label: String) -> void:
	for frame in 5: await process_frame
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png(output.path_join(label+".png"))
func _run() -> void:
	create_timer(60).timeout.connect(func(): quit(1))
	await process_frame
	var args := OS.get_cmdline_user_args()
	output=args[0] if not args.is_empty() else ProjectSettings.globalize_path("res://../outputs/validated-biomes")
	DirAccess.make_dir_recursive_absolute(output)
	viewport=SubViewport.new()
	viewport.size=Vector2i(1280,720)
	viewport.own_world_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var dungeon=load("res://scenes/dungeon/dungeon_manager.tscn").instantiate()
	viewport.add_child(dungeon)
	var hero=dungeon.get_node("MeleeHero")
	hero.set_physics_process(false)
	for number in range(1,4):
		dungeon.floor_number=number
		dungeon.dungeon_seed=1337
		dungeon._load_floor()
		hero.camera_rig.restore_view(0,deg_to_rad(-40))
		await capture("biome-%d-player" % number)
		var corner: Vector2i=dungeon.floor_generator.spawn_cell
		for cell: Vector2i in dungeon.floor_generator.layout.walkable:
			if not dungeon.floor_generator.layout.walkable.has(cell+Vector2i.DOWN) and not dungeon.floor_generator.layout.walkable.has(cell+Vector2i.RIGHT): corner=cell
		hero.position=dungeon.floor_generator.cell_to_world(corner)+Vector3.UP*0.1
		hero.camera_rig.restore_view(0,deg_to_rad(-40))
		await capture("biome-%d-corner" % number)
		hero.camera_rig.orbit(-0.8,deg_to_rad(-20))
		for frame in 30:
			hero.camera_rig.update(0.016)
			await process_frame
		await capture("biome-%d-manual-steep" % number)
		var camera:=Camera3D.new()
		dungeon.add_child(camera)
		if number==3:
			var landmark=dungeon.floor_generator.content.get_node("DungeonLandmarks/DistantRailLandmark")
			var loco=landmark.get_node("locomotive")
			camera.global_position=loco.global_position+Vector3(7,4,8)
			camera.look_at(loco.global_position+Vector3(0,1,0))
		elif number==2:
			var detail=dungeon.floor_generator.content.get_node("DungeonLandmarks/ImportedFrostDetails/valve")
			camera.global_position=detail.global_position+Vector3(1.1,0.6,1.6)
			camera.look_at(detail.global_position)
		else:
			var guard=dungeon.floor_generator.guard
			camera.global_position=guard.global_position+Vector3(2.6,2.2,4)
			camera.look_at(guard.global_position+Vector3(0,1,0))
		camera.make_current()
		await capture("biome-%d-landmark-or-guard" % number)
		camera.free()
		hero.camera.make_current()
	quit()
