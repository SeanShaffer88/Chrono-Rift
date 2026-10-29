extends "res://tests/test_harness_template.gd"
const Layout=preload("res://scripts/utilities/menu_layout.gd")
const Rows=preload("res://scenes/ui/paged_rows.gd")
const TextPages=preload("res://scenes/ui/paged_text.gd")
const Menu=preload("res://scenes/ui/character_menu.gd")
const Title=preload("res://scenes/ui/major_title.gd")
const Services=preload("res://scripts/utilities/services.gd")
func settle() -> void:
	for frame in 4: await process_frame
func inside(control: Control,area: Rect2) -> bool:
	var rect := control.get_global_rect()
	return area.grow(1).encloses(rect)
func run_assertions() -> void:
	var mobile := Layout.metrics_for(480,2,true)
	check(mobile.touch==72 and mobile.primary==80 and mobile.body==24 and mobile.secondary==21,"Mobile metrics honor48dp targets and16sp text at480DPI/2x")
	var dense := Layout.metrics_for(640,1.5,true)
	check(dense.touch*1.5>=48*4 and dense.body*1.5>=16*4,"High density metrics never cap targets or fonts below requested physical density")
	var m := Layout.metrics_for(96,1,false)
	var rows := Rows.new()
	root.add_child(rows)
	rows.position=Vector2(16,16)
	rows.size=Vector2(310,330)
	var entries: Array[Dictionary]=[]
	for index in 127: entries.append({"id":"part:%d"%index,"label":"Recovered part %d"%index})
	rows.set_entries(entries)
	rows.configure(Vector2(310,330),m)
	await settle()
	var ids := {}
	while true:
		for button: Button in rows.row_buttons:
			if button.visible:
				ids[button.get_meta("id")]=true
				check(inside(button,Rect2(16,16,310,330)),"Paged row stays inside its bounded list")
		if rows.next.disabled: break
		rows.change_page(1)
		await process_frame
	check(ids.size()==127 and rows.row_buttons.size()<=10,"Every long-list ID is reachable with bounded reusable controls and no scrolling")
	rows.choose("part:126")
	var chosen: String=rows.selected_id
	var before: int=rows.capacity
	entries[0].label="A much longer foundation label that wraps onto several readable lines"
	rows.set_entries(entries,chosen)
	check(rows.capacity<before and rows.selected_id==chosen,"A changed dataset remeasures rows without changing the selected object ID")
	rows.choose("unknown")
	check(rows.selected_id==chosen,"Unknown row selection cannot replace a stable selected ID")
	check(rows.find_children("*","ScrollContainer",true,false).is_empty() and rows.find_children("*","ItemList",true,false).is_empty(),"Paged list owns no scrolling widgets")
	rows.queue_free()
	var text := TextPages.new()
	root.add_child(text)
	text.position=Vector2(16,16)
	text.size=Vector2(600,320)
	text.configure(Vector2(600,320),m)
	var full := ""
	for index in 100: full+="Request %d: Preserve every word, punctuation and Ω symbol.\n"%index
	text.text=full
	await settle()
	check(text.pages.size()>1 and "".join(text.pages)==full,"Wrapped text pages preserve every original character")
	text.change_page(10000)
	await settle()
	check(text.page_index==text.pages.size()-1 and text.next.disabled and inside(text.footer,Rect2(16,16,600,320)),"Long text reaches its final page with navigation inside bounds")
	text.queue_free()
	var state=Services.game_state()
	state.reset()
	var hero=load("res://scenes/characters/melee_hero.tscn").instantiate()
	root.add_child(hero)
	hero.set_physics_process(false)
	var menu := Menu.new()
	menu.hero=hero
	root.add_child(menu)
	menu.open_menu()
	await settle()
	check(not menu.card_by_id.devourer.visible and menu.capacity==4 and menu.card_grid.columns==2,"Normal1280 window preserves four cards and omits locked secret before paging")
	menu.close_menu()
	state.record_floor_clear(6)
	menu.open_menu()
	await settle()
	var full_size: Vector2=menu.panel.size
	menu.change_page(1)
	await settle()
	check(menu.card_by_id.devourer.visible and menu.card_grid.columns==1 and menu.panel.size.x<full_size.x and menu.panel.size.y<full_size.y,"Single-card page fits its actual content without empty column or row")
	check(inside(menu.panel,Layout.safe_rect(root)) and inside(menu.close,Layout.safe_rect(root)),"Characters panel and pinned actions stay inside safe bounds")
	check(menu.note.visible and menu.footer.visible and not menu.labels.devourer[2].visible,"Explanations remain reachable while identical weaponless text is deduplicated")
	check(menu.find_children("*","ScrollContainer",true,false).is_empty(),"Characters menu has no scroll container")
	menu.close_menu()
	menu.queue_free()
	hero.queue_free()
	await settle()
	state.collect_restoration_orb("fit-unplaced","mayor_house")
	var town=load("res://scenes/georama/georama_manager.tscn").instantiate()
	root.add_child(town)
	town.show_page("move")
	await settle()
	var object_id: String=town.foundation_ids[0]
	town.selected_id=object_id
	town._refresh_slots()
	var parts: Dictionary=state.collected_orb_ids.duplicate(true)
	check(town._remove_button.disabled and not town.grid.remove(object_id) and state.collected_orb_ids==parts,"Unplaced foundation cannot be removed or consume parts")
	town._foundations.choose(object_id)
	check(town.pending_id==object_id and is_instance_valid(town._preview),"Move page exposes unplaced foundations and opens their placement preview")
	town._confirm.pressed.emit()
	check(state.town_objects[object_id].placed,"Placement Confirm remains reachable through the Move workflow")
	town.queue_free()
	await settle()
	var joystick=load("res://scenes/ui/virtual_joystick.tscn").instantiate()
	root.add_child(joystick)
	var safe := Layout.safe_rect(root)
	for point in [Vector2(-1000,-1000),Vector2(10000,-1000),Vector2(-1000,10000),Vector2(10000,10000)]:
		joystick._update_knob(point)
		check(safe.encloses(Rect2(joystick._base_pos-Vector2.ONE*joystick.radius,Vector2.ONE*joystick.radius*2)) and safe.encloses(Rect2(joystick._knob_pos-Vector2.ONE*joystick.knob_radius,Vector2.ONE*joystick.knob_radius*2)),"Extreme drag keeps both drawn joystick circles inside safe bounds")
		check(joystick.get_vector().length()>0.99,"Safe knob rendering does not weaken movement input")
	joystick.queue_free()
	await test_titles()
	await test_title_triggers()
	state.reset()
func test_titles() -> void:
	var title := Title.new()
	root.add_child(title)
	title.animate_titles=false
	var starts: Array[StringName]=[]
	var finishes: Array[StringName]=[]
	title.started.connect(func(key: StringName): starts.append(key))
	title.finished.connect(func(key: StringName): finishes.append(key))
	title.show_title(&"biome","FOUNDRY",&"a")
	title.show_title(&"biome","FOUNDRY",&"a")
	title.show_title(&"biome","FROZEN FRONTIER",&"b")
	title.show_title(&"biome","OVERGROWN RAILS",&"c")
	check(starts.size()==1 and title.pending.key==&"c","Title duplicates are ignored and latest queued biome replaces stale one")
	title.show_title(&"unlock","DEVOURER UNLOCKED",&"unlock")
	title.show_title(&"biome","FOUNDRY",&"d")
	title.show_title(&"biome","FROZEN FRONTIER",&"e")
	check(title.active.key==&"unlock" and title.pending.key==&"e" and title.get_child_count()==9,"Unlock preempts biome with at most active plus one queued and nine reusable labels")
	title._resize_title()
	check(starts.size()==2 and title.active.key==&"unlock","Resize completes reveal without restarting the announcement")
	await create_timer(1.21).timeout
	check(title.active.get("key")==&"e" and finishes==[&"unlock"],"Static title completes once and dispatches its queued entry")
	await create_timer(1.21).timeout
	check(title.active.is_empty() and not title.visible and finishes==[&"unlock",&"e"],"Queued title completes without stale callbacks")
	title.animate_titles=true
	title.show_title(&"biome","ONE TWO THREE FOUR FIVE SIX SEVEN EIGHT NINE",&"long")
	check(title.fallback.visible and title.get_child_count()==9,"Long titles fall back to one wrapped label without new nodes")
	title.finish_reveal()
	check(title.fallback.modulate.a==1 and title.mouse_filter==Control.MOUSE_FILTER_IGNORE,"Finish reveal exposes text without capturing input")
	title.cancel()
	await create_timer(0.1).timeout
	check(title.active.is_empty() and title.pending.is_empty() and finishes.size()==2,"Cancellation clears queue and invalidates completion callbacks")
	title.queue_free()
func test_title_triggers() -> void:
	var state=Services.game_state()
	state.reset()
	var dungeon=load("res://scenes/dungeon/dungeon_manager.tscn").instantiate()
	dungeon.animate_titles=false
	root.add_child(dungeon)
	var keys: Array[StringName]=[]
	dungeon.major_title.started.connect(func(key: StringName): keys.append(key))
	await settle()
	check(keys==[&"biome:foundry:floor:1"],"Startup announces its final entry exactly once")
	dungeon._load_floor()
	check(keys.size()==1,"Same-floor reload does not replay a title")
	dungeon.open_town()
	check(dungeon.major_title.active.is_empty(),"Town entry cancels title and pending animation")
	dungeon.close_town()
	check(keys.size()==1,"Returning from town does not replay current entry")
	dungeon.get_node("MeleeHero").take_damage(999)
	check(dungeon.major_title.active.is_empty() and dungeon.retry_floor() and keys.size()==1,"Death cancels and retry deduplicates the current title")
	state.record_floor_clear(6)
	state.record_floor_clear(7)
	check(keys.count(&"unlock:devourer")==1,"Only the first real unlock transition emits its title")
	dungeon.major_title.cancel()
	dungeon.floor_number=5
	dungeon._load_floor()
	var Data=preload("res://scripts/persistence/save_data.gd")
	var Store=preload("res://scripts/persistence/save_store.gd")
	var path := "user://verification-title-%d.json"%OS.get_process_id()
	var store=Store.new(path,Data.validate)
	check(store.write_save(Data.capture(state,dungeon))==OK,"Isolated title-startup save is valid")
	dungeon.queue_free()
	await settle()
	state.reset()
	dungeon=load("res://scenes/dungeon/dungeon_manager.tscn").instantiate()
	root.add_child(dungeon)
	keys.clear()
	dungeon.major_title.started.connect(func(key: StringName): keys.append(key))
	dungeon.start_saving(path)
	await settle()
	check(keys==[&"biome:frost:floor:5"],"Restore gates initial floor1 and announces only the restored floor")
	dungeon.queue_free()
	await settle()
	for suffix in ["",".bak",".tmp",".bak.tmp"]:
		if FileAccess.file_exists(path+suffix): DirAccess.remove_absolute(path+suffix)
