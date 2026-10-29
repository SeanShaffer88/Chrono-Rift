extends SceneTree
## Actual runtime art and menu capture; no concept image is rendered in-game.
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
	var hero = dungeon.get_node("MeleeHero")
	hero.set_physics_process(false)
	hero.visual.rotation.y = PI
	var state = root.get_node("GameState")
	for id in ["melee_hero", "swordsman", "riftwarden"]:
		state.swap_character(id)
		for i in 10: await process_frame
		await RenderingServer.frame_post_draw
		viewport.get_texture().get_image().save_png(output.path_join("Roster-" + id + ".png"))
	var menu = null
	for child in dungeon.get_node("TouchUI").get_children():
		if child.has_method("open_menu"):
			menu = child
	menu.open_menu()
	for i in 10: await process_frame
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png(output.path_join("Roster-menu.png"))
	menu.close_menu()
	quit()
