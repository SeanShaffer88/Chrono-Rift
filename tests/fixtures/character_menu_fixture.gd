extends SceneTree
const Menu = preload("res://scenes/ui/character_menu.gd")
func _init() -> void: run.call_deferred()
func run() -> void:
	var viewport := SubViewport.new()
	viewport.size=Vector2i(1280,720)
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var hero=load("res://scenes/characters/melee_hero.tscn").instantiate()
	viewport.add_child(hero)
	hero.set_physics_process(false)
	var layer := CanvasLayer.new()
	viewport.add_child(layer)
	var menu := Menu.new()
	menu.hero=hero
	layer.add_child(menu)
	menu.open_menu()
	for size: Vector2i in [Vector2i(1280,720),Vector2i(390,700)]:
		viewport.size=size
		for frame in 5: await process_frame
		await RenderingServer.frame_post_draw
		var close=menu.find_child("CloseButton",true,false)
		var rect: Rect2=close.get_global_rect()
		if rect.end.y>size.y or rect.position.x<0 or rect.end.x>size.x:
			push_error("Close button exceeds viewport: "+str(rect))
			quit(1)
			return
		if menu.card_grid.columns != (2 if size.x>=680 else 1):
			quit(1)
			return
		viewport.get_texture().get_image().save_png("res://../outputs/Battlemage-menu-%d.png"%size.x)
		print("PASS responsive menu ",size," close ",rect)
	var state=root.get_node("GameState")
	menu.close_menu()
	state.record_floor_clear(6)
	menu.open_menu()
	for frame in 5: await process_frame
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png("res://../outputs/Devourer-menu-unlocked.png")
	menu.close_menu()
	quit()
