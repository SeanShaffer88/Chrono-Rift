extends SceneTree
## Graphical smoke capture: actual dungeon, plus a close view of its key guard.
func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	create_timer(45).timeout.connect(func(): quit(1))
	await process_frame
	var args := OS.get_cmdline_user_args()
	var output := ProjectSettings.globalize_path("res://../outputs") if args.is_empty() else args[0]
	DirAccess.make_dir_recursive_absolute(output)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var dungeon = load("res://scenes/dungeon/dungeon_manager.tscn").instantiate()
	viewport.add_child(dungeon)
	for i in 30: await process_frame
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png(output.path_join("Visual-pass-dungeon.png"))
	var hero = dungeon.get_node("MeleeHero")
	hero.position = dungeon.floor_generator.guard.position + Vector3(0, 0.1, 3)
	for i in 30: await process_frame
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png(output.path_join("Visual-pass-guard.png"))
	hero.set_physics_process(false)
	var gate = dungeon.floor_generator.content.get_node("ExitGate")
	var camera := Camera3D.new()
	dungeon.add_child(camera)
	camera.position = gate.global_position + Vector3(0,1.7,2.8)
	camera.look_at(gate.global_position + Vector3(0,1.25,0), Vector3.UP)
	camera.make_current()
	for i in 10: await process_frame
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png(output.path_join("Graphics-locked-gate.png"))
	dungeon.floor_generator.key_collected = true
	gate._update_gate()
	for i in 10: await process_frame
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png(output.path_join("Graphics-unlocked-gate.png"))
	quit()
