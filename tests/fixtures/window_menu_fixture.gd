extends Node
var ready_for_capture := false
func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	var window := get_tree().root
	window.title="Chrono Rift - Native Window QA"
	preload("res://scripts/utilities/desktop_window.gd").configure(window)
	window.show()
	var dungeon=load("res://scenes/dungeon/dungeon_manager.tscn").instantiate()
	add_child(dungeon)
	dungeon.get_node("MeleeHero").set_physics_process(false)
	dungeon.floor_generator.guard.set_physics_process(false)
	for enemy: Node in dungeon.floor_generator.encounters.values(): enemy.set_physics_process(false)
	get_tree().root.get_node("GameState").record_floor_clear(6)
	for child: Node in dungeon.get_node("TouchUI").get_children():
		if child.get_script()==preload("res://scenes/ui/character_menu.gd"): child.open_menu()
	ready_for_capture=true
	window.size_changed.connect(observe)
	observe.call_deferred()
func observe() -> void:
	if not ready_for_capture: return
	for frame in 4: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var window := get_tree().root
	var before_mode := window.mode
	var before_size := window.size
	preload("res://scripts/utilities/desktop_window.gd").configure(window)
	print("WINDOW_REPEAT_CONFIG ",window.mode==before_mode and window.size==before_size)
	var label := "maximized" if window.mode==Window.MODE_MAXIMIZED else "normal"
	var output := ProjectSettings.globalize_path("res://../outputs/window-native-"+label+".png")
	window.get_texture().get_image().save_png(output)
	print("WINDOW_QA ",JSON.stringify({"mode":window.mode,"size":[window.size.x,window.size.y],"unresizable":window.unresizable,"maximize_disabled":window.maximize_disabled,"minimize_disabled":window.minimize_disabled,"borderless":window.borderless}))
