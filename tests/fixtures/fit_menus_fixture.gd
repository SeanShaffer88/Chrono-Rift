extends SceneTree
var viewport: SubViewport
var output := ""
func _init() -> void: run.call_deferred()
func capture(label: String) -> void:
	for frame in 5: await process_frame
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png(output.path_join(label+".png"))
func run() -> void:
	output=ProjectSettings.globalize_path("res://../outputs/fit-menu-native")
	DirAccess.make_dir_recursive_absolute(output)
	viewport=SubViewport.new()
	viewport.size=Vector2i(1280,720)
	viewport.own_world_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var hero=load("res://scenes/characters/melee_hero.tscn").instantiate()
	viewport.add_child(hero)
	hero.set_physics_process(false)
	var layer := CanvasLayer.new()
	viewport.add_child(layer)
	var menu := preload("res://scenes/ui/character_menu.gd").new()
	menu.hero=hero
	layer.add_child(menu)
	menu.open_menu()
	await capture("characters-locked-1280")
	menu.close_menu()
	var state=root.get_node("GameState")
	state.record_floor_clear(6)
	menu.open_menu()
	await capture("characters-unlocked-page1-1280")
	menu.change_page(1)
	await capture("characters-unlocked-page2-1280")
	print("PAGE2 panel=",menu.panel.get_rect()," minimum=",menu.panel.get_combined_minimum_size()," grid=",menu.card_grid.get_combined_minimum_size()," content=",menu.content.get_combined_minimum_size())
	for card: Control in menu.cards:
		if card.visible: print("VISIBLE CARD ",card.name," size=",card.size," min=",card.get_combined_minimum_size())
	viewport.size=Vector2i(1600,720)
	await capture("characters-wide-1600")
	menu.close_menu()
	layer.queue_free()
	hero.queue_free()
	await process_frame
	viewport.size=Vector2i(1280,720)
	for index in 80:
		state.collect_restoration_orb("fit-foundation:%d"%index,"mayor_house")
		state.collect_restoration_orb("fit-component:%d"%index,"mayor_roof")
	var town=load("res://scenes/georama/georama_manager.tscn").instantiate()
	viewport.add_child(town)
	await capture("town-assembly-1280")
	town._foundations.change_page(1)
	town._components.change_page(1)
	await capture("town-list-page2-1280")
	town.show_analysis()
	await capture("town-analysis-first-1280")
	town._dialog_text.change_page(10000)
	await capture("town-analysis-last-1280")
	town._dialog.hide()
	viewport.size=Vector2i(1600,720)
	await capture("town-wide-1600")
	var audio=root.get_node_or_null("GameState/CombatAudio")
	if audio!=null: audio.queue_free()
	await create_timer(0.1).timeout
	print("FIT_MENU_CAPTURE_COMPLETE")
	quit()
