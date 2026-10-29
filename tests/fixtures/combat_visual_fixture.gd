extends SceneTree
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
	var hero = dungeon.get_node("MeleeHero")
	var guard = dungeon.floor_generator.guard
	hero.position = guard.position + Vector3(0, 0.1, 1.5)
	hero.face_direction(Vector3.FORWARD)
	hero.force_lock_on = true
	hero.update_lock_on()
	hero.camera_rig.snap()
	guard.set_physics_process(false)
	guard.target = hero
	guard.rotation.y = PI
	guard._set_state(guard.State.WINDUP)
	for i in 30: await process_frame
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png(output.path_join("Combat-windup.png"))
	hero.take_damage(999)
	for i in 10: await process_frame
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png(output.path_join("Combat-defeat.png"))
	dungeon.retry_floor()
	for i in 20: await process_frame
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png(output.path_join("Combat-retry.png"))
	quit()
