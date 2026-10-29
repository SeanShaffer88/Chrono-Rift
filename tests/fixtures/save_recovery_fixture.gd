extends SceneTree
var viewport: SubViewport
var path := "user://verification-recovery-ui-%d.json"%OS.get_process_id()
var output := ""
func _init() -> void: run.call_deferred()
func capture(name: String) -> void:
	for frame in 6: await process_frame
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png(output.path_join(name+".png"))
func run() -> void:
	output=ProjectSettings.globalize_path("res://../outputs/save-recovery-native")
	DirAccess.make_dir_recursive_absolute(output)
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JSON.stringify({"version":3,"fixture":"owned isolated file"}))
	file.close()
	viewport=SubViewport.new()
	viewport.size=Vector2i(1280,720)
	viewport.own_world_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	root.get_node("GameState").reset()
	var dungeon=load("res://scenes/dungeon/dungeon_manager.tscn").instantiate()
	viewport.add_child(dungeon)
	dungeon.get_node("MeleeHero").set_physics_process(false)
	dungeon.floor_generator.guard.set_physics_process(false)
	for enemy: Node in dungeon.floor_generator.encounters.values(): enemy.set_physics_process(false)
	dungeon.start_saving(path)
	await capture("blocked-status-1280")
	var menu=dungeon.get_node("TouchUI/SaveRecoveryMenu")
	menu.open_details()
	await capture("confirm-1280")
	menu.close_details()
	menu.open_details()
	menu.confirm_fresh()
	await capture("complete-1280")
	menu.close_details()
	var archive: String=preload("res://scripts/persistence/save_recovery.gd").journal_state(path).archive
	viewport.queue_free()
	await process_frame
	for name: String in preload("res://scripts/persistence/save_recovery.gd").NAMES+["manifest.json"]:
		DirAccess.remove_absolute(archive.path_join(name))
	DirAccess.remove_absolute(archive)
	for suffix in ["",".bak",".tmp",".bak.tmp",".recovery.json"]:
		if FileAccess.file_exists(path+suffix): DirAccess.remove_absolute(path+suffix)
	var audio=root.get_node_or_null("GameState/CombatAudio")
	if audio!=null: audio.queue_free()
	await create_timer(0.1).timeout
	print("RECOVERY_CAPTURE COMPLETE")
	quit()
