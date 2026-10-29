extends Node
const Layout=preload("res://scripts/utilities/menu_layout.gd")
const Menu=preload("res://scenes/ui/character_menu.gd")
var failures := 0
var assertions := 0
var dungeon: Node
var starts: Array[StringName]=[]
@export var info_only := false
func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	run.call_deferred()
func check(value: bool,label: String) -> void:
	assertions+=1
	if not value: failures+=1
	print("MENU_QA "+("PASS: " if value else "FAIL: ")+label)
func settle() -> void:
	for frame in 6: await get_tree().process_frame
func capture(label: String) -> void:
	await settle()
	print("MENU_QA CAPTURE: "+label)
	await get_tree().create_timer(1.0).timeout
func tap(button: Button) -> void:
	for pressed in [true,false]:
		var event := InputEventScreenTouch.new()
		event.index=7
		event.position=button.get_global_rect().get_center()
		event.pressed=pressed
		get_viewport().push_input(event,true)
		await get_tree().process_frame
func stop_actors() -> void:
	dungeon.get_node("MeleeHero").set_physics_process(false)
	dungeon.floor_generator.guard.set_physics_process(false)
	for enemy: Node in dungeon.floor_generator.encounters.values(): enemy.set_physics_process(false)
func check_buttons(node: Node,label: String) -> void:
	var safe := Layout.safe_rect(get_viewport()).grow(1)
	var good := true
	var count := 0
	var smallest := INF
	var transform := get_viewport().get_screen_transform()
	var dpi := maxf(DisplayServer.screen_get_dpi(),160)
	var minimum_dp := INF
	for control: Node in node.find_children("*","Button",true,false):
		if not control.is_visible_in_tree(): continue
		count+=1
		var rect: Rect2=control.get_global_rect()
		if not safe.encloses(rect): print("MENU_QA BOUNDS ",label," ",control.get_path()," rect=",rect," safe=",safe)
		good=good and safe.encloses(rect)
		smallest=minf(smallest,rect.size.y)
		var physical: Rect2=transform*rect
		minimum_dp=minf(minimum_dp,minf(physical.size.x,physical.size.y)*160/dpi)
	check(count>0 and good,label+" visible button bounds (count %d)"%count)
	check(not OS.has_feature("android") or minimum_dp>=47.9,label+" physical targets >=48 dp (minimum %.2f dp)"%minimum_dp)
func menu_for(parent: Node) -> Menu:
	for child: Node in parent.get_children():
		if child.get_script()==Menu: return child
	return null
func run() -> void:
	if info_only:
		await run_info()
		return
	var state=get_tree().root.get_node("GameState")
	state.reset()
	dungeon=load("res://scenes/dungeon/dungeon_manager.tscn").instantiate()
	add_child(dungeon)
	dungeon.major_title.started.connect(func(key: StringName): starts.append(key))
	await settle()
	stop_actors()
	var viewport := get_viewport()
	var transform := viewport.get_screen_transform()
	print("MENU_QA METRICS ",JSON.stringify({"dpi":DisplayServer.screen_get_dpi(),"scale_x":transform.x.length(),"scale_y":transform.y.length(),"viewport":str(viewport.get_visible_rect()),"physical_safe":str(DisplayServer.get_display_safe_area()),"logical_safe":str(Layout.safe_rect(viewport)),"metrics":Layout.metrics(viewport)}))
	check(dungeon.save_session==null,"QA fixture never loads shipping save")
	check(starts==[&"biome:foundry:floor:1"],"Startup announces current biome once")
	await capture("dungeon-safe-touch")
	check_buttons(dungeon.get_node("TouchUI"),"Dungeon HUD")
	var actions_fit := true
	for child: Node in dungeon.get_node("TouchUI").get_children():
		if child.get_script()==preload("res://scenes/ui/touch_action_button.gd"):
			actions_fit=actions_fit and Layout.safe_rect(get_viewport()).encloses(child.get_global_rect()) and ThemeDB.fallback_font.get_string_size(child.label_text,HORIZONTAL_ALIGNMENT_LEFT,-1,child.font_size).x<=child.size.x
	check(actions_fit,"Every touch action and its full caption fits safe bounds")
	var menu := menu_for(dungeon.get_node("TouchUI"))
	menu.open_menu()
	await capture("characters-locked")
	check(menu.available_ids.size()==4,"Locked secret filtered before pagination")
	for page in ceili(float(menu.available_ids.size())/menu.capacity):
		menu.change_page(page-menu.page_index)
		await settle()
		check_buttons(menu,"Locked character page %d"%page)
	var roster_page := menu.page_index
	menu.set_view(&"info")
	await capture("characters-info")
	check("".join(menu.info.pages)==menu.info.text and not menu.info.text.contains("Devourer"),"Info preserves full explanations and filters locked secret")
	for page in menu.get_page_count():
		menu.set_page(page)
		await settle()
		check_buttons(menu,"Character info page %d"%page)
		check(menu.info.body_holder.get_global_rect().end.y<=menu.pager.get_global_rect().position.y+1,"Info body and pinned footer never overlap")
	menu.set_view(&"roster")
	check(menu.page_index==roster_page,"Info returns to the previous roster page")
	menu.close_menu()
	dungeon.floor_number=6
	dungeon._load_floor()
	stop_actors()
	var hero=dungeon.get_node("MeleeHero")
	dungeon.floor_generator.guard.receive_hit(999,hero)
	check(dungeon.floor_generator.try_collect_key(hero),"Floor6 actual key gate acknowledges collection")
	check(dungeon.floor_generator.try_exit(hero),"Floor6 actual exit acknowledges clear")
	await settle()
	stop_actors()
	check(state.secret_unlocked and dungeon.floor_number==7 and starts.count(&"unlock:devourer")==1,"Actual exit unlocks Devourer and announces once")
	await capture("unlock-title")
	menu.open_menu()
	for page in ceili(float(menu.available_ids.size())/menu.capacity):
		menu.change_page(page-menu.page_index)
		await capture("characters-unlocked-page-%d"%page)
		check_buttons(menu,"Unlocked character page %d"%page)
	menu.close_menu()
	dungeon.open_town()
	await settle()
	var town=dungeon.town_view
	for index in 65:
		state.collect_restoration_orb("mobile-foundation:%d"%index,"mayor_house")
		state.collect_restoration_orb("mobile-component:%d"%index,"mayor_roof")
	town.grid.sync_parts()
	town._refresh()
	await capture("town-assembly")
	check_buttons(town,"Town assembly")
	town.show_page("move")
	var object_id: String=town.foundation_ids[0]
	var resources_before: Dictionary=state.collected_orb_ids.duplicate(true)
	town.selected_id=object_id
	town._refresh_slots()
	check(town._remove_button.disabled and not town.grid.remove(object_id) and state.collected_orb_ids==resources_before,"Unplaced foundation Remove is disabled and cannot consume recovered parts")
	town._foundations.choose(object_id)
	await settle()
	check(town.pending_id==object_id and is_instance_valid(town._preview),"Move page selects unplaced foundation into reachable placement preview")
	await capture("town-placement")
	check_buttons(town,"Town placement")
	town._confirm.pressed.emit()
	check(state.town_objects[object_id].placed,"Confirm places recovered foundation through compact UI")
	town.show_page("assembly")
	for page in ceili(float(town._foundations.entries.size())/town._foundations.capacity):
		town._foundations.change_page(page-town._foundations.page_index)
		await settle()
	check(town._foundations.page_index==ceili(float(town._foundations.entries.size())/town._foundations.capacity)-1,"Long town inventory reaches final bounded page")
	await capture("town-last-page")
	check_buttons(town,"Town final page")
	town.show_analysis()
	await capture("town-analysis-first")
	var text: String=town._dialog_text.text
	check("".join(town._dialog_text.pages)==text,"Analysis pages preserve complete text")
	town._dialog_text.change_page(10000)
	await capture("town-analysis-last")
	check_buttons(town,"Town analysis")
	town._dialog.hide()
	town._back()
	await capture("town-commands")
	check_buttons(town,"Town commands")
	town.set_editing(false)
	await capture("town-walk")
	check_buttons(town,"Town walk")
	town.talk_nearest()
	town._dialog_text.text="Long resident request.\n".repeat(60)
	town._layout_ui()
	await settle()
	town._dialog_text.change_page(1)
	await tap(town._dialog_text.previous)
	check(town._dialog_text.page_index==0 and town._joystick._touch_index==-1 and not town._joystick.visible,"Viewport touch Previous is not stolen by walking joystick")
	await tap(town._dialog_back)
	check(not town._dialog.visible and town._joystick.visible and town._joystick._touch_index==-1,"Viewport touch Back closes dialog and restores idle walking joystick")
	dungeon.close_town()
	var before := starts.size()
	check(dungeon.major_title.active.is_empty(),"Town cancels title without replay on return")
	hero.take_damage(999)
	print("MENU_QA DEFEAT target=",dungeon._defeat_size," actual=",dungeon._defeat_ui.size," min=",dungeon._defeat_ui.get_combined_minimum_size()," note=",dungeon._defeat_note.get_combined_minimum_size())
	await capture("defeat")
	check_buttons(dungeon._defeat_ui,"Defeat")
	check(dungeon.retry_floor(),"Retry remains reachable")
	await settle()
	stop_actors()
	check(starts.size()==before,"Retry suppresses current entry title")
	var path := "user://menu-title-qa.json"
	dungeon.start_saving(path)
	check(dungeon.save_session!=null,"Isolated saving starts")
	dungeon.save_session.flush()
	dungeon.queue_free()
	await settle()
	state.reset()
	dungeon=load("res://scenes/dungeon/dungeon_manager.tscn").instantiate()
	add_child(dungeon)
	starts.clear()
	dungeon.major_title.started.connect(func(key: StringName): starts.append(key))
	dungeon.start_saving(path)
	await settle()
	stop_actors()
	check(starts==[&"biome:foundry:floor:7"],"Save restore announces restored floor only")
	await capture("restored-title")
	print("MENU_QA COMPLETE failures=%d assertions=%d"%[failures,assertions])
func run_info() -> void:
	var state=get_tree().root.get_node("GameState")
	state.reset()
	var hero=load("res://scenes/characters/melee_hero.tscn").instantiate()
	add_child(hero)
	hero.set_physics_process(false)
	var layer := CanvasLayer.new()
	add_child(layer)
	var menu := Menu.new()
	menu.hero=hero
	layer.add_child(menu)
	menu.open_menu()
	menu.set_view(&"info")
	await settle()
	print("MENU_QA INFO_SAFE ",Layout.safe_rect(get_viewport()))
	check("".join(menu.info.pages)==menu.info.text,"Full Info text remains reachable without loss")
	for page in menu.get_page_count():
		menu.set_page(page)
		await settle()
		check_buttons(menu,"Info correction page %d"%page)
		check(menu.info.body_holder.get_global_rect().end.y<=menu.pager.get_global_rect().position.y+1,"Info text holder ends before pinned footer")
		check(Layout.text_height(menu.info.body.text,menu.info.body_holder.size.x,Layout.metrics(get_viewport()).body)<=menu.info.body_holder.size.y+1,"Complete shaped page text fits its allocated height")
		await capture("characters-info-fixed-page-%d"%page)
	await tap(menu.info_button)
	check(menu.view_mode==&"roster","Viewport Roster toggle returns from Info")
	await tap(menu.close)
	check(not menu.opened and not get_tree().paused,"Viewport Close releases menu pause")
	print("MENU_QA COMPLETE failures=%d assertions=%d"%[failures,assertions])
