extends Node
const Services=preload("res://scripts/utilities/services.gd")
const Data=preload("res://scripts/persistence/save_data.gd")
const Menu=preload("res://scenes/ui/character_menu.gd")
var failures := 0
func _ready() -> void: run.call_deferred()
func check(value: bool,label: String) -> void:
	if not value: failures+=1
	print("HERO_QA "+("PASS: " if value else "FAIL: ")+label)
func capture(label: String) -> void:
	for frame in 3: await get_tree().process_frame
	print("HERO_QA CAPTURE: "+label)
	await get_tree().create_timer(1.2).timeout
func menu_for(dungeon: Node) -> Control:
	for child: Node in dungeon.get_node("TouchUI").get_children():
		if child.get_script()==Menu: return child
	return null
func run() -> void:
	var state=Services.game_state()
	state.reset()
	var path="user://verification-hero-schema3-%d.json"%OS.get_process_id()
	var dungeon=load("res://scenes/dungeon/dungeon_manager.tscn").instantiate()
	add_child(dungeon)
	var hero=dungeon.get_node("MeleeHero")
	hero.set_physics_process(false)
	check(dungeon.save_session==null,"Fresh isolated fixture never opens shipping save")
	check(not state.is_character_available("devourer") and not state.swap_character("devourer"),"Secret is hidden and selection locked initially")
	var menu=menu_for(dungeon)
	menu.open_menu()
	check(not menu.buttons.devourer.get_parent().visible,"Locked menu contains no secret card")
	await capture("menu-locked")
	menu.close_menu()
	dungeon.floor_number=5
	dungeon._load_floor()
	dungeon.floor_generator.guard.set_physics_process(false)
	check(not state.secret_unlocked,"Generating floor five does not unlock secret")
	dungeon.floor_generator.guard.receive_hit(60,hero)
	check(not state.secret_unlocked,"Guard defeat alone does not unlock secret")
	check(dungeon.floor_generator.try_collect_key(hero) and dungeon.floor_generator.try_exit(hero),"Floor five exits through actual acknowledged key and exit path")
	for frame in 3: await get_tree().process_frame
	check(dungeon.floor_number==6 and not state.secret_unlocked,"Clearing floor five advances without unlock")
	dungeon.floor_generator.guard.set_physics_process(false)
	hero.take_damage(999)
	check(dungeon.retry_floor(),"Actual floor six retry succeeds after defeat")
	check(not state.secret_unlocked,"Retrying floor six does not unlock secret")
	dungeon.floor_generator.guard.set_physics_process(false)
	dungeon.floor_generator.guard.receive_hit(60,hero)
	check(dungeon.floor_generator.try_collect_key(hero) and dungeon.floor_generator.try_exit(hero),"Floor six clear uses actual exit acknowledgment")
	for frame in 3: await get_tree().process_frame
	check(dungeon.floor_number==7 and state.secret_unlocked,"Actual floor six clear persistently unlocks secret")
	dungeon.floor_generator.guard.set_physics_process(false)
	menu.open_menu()
	check(menu.buttons.devourer.get_parent().visible,"Unlocked menu exposes fifth card")
	await capture("menu-unlocked")
	menu.close_menu()
	for id in ["melee_hero","swordsman","riftwarden","battlemage","devourer"]:
		check(state.swap_character(id),"Selectable current hero "+id)
		await capture("hero-"+id)
	check(hero.weapon_inventory.get_weapons().is_empty() and hero.weapon_inventory.equipped_weapon==null,"Devourer has no hidden weapon")
	var target=dungeon.floor_generator.guard
	target.position=hero.position+Vector3.FORWARD
	check(hero.request_attack(),"Devourer starts shared melee cadence")
	hero.tick_combat(0.11)
	hero._on_weapon_hitbox_area_entered(target.get_node("Hurtbox"))
	check(target.current_hp==0 and hero.weapon_hitbox.last_resolved_damage==60,"Normal enemy swallowed through acknowledged hit")
	await capture("devourer-swallow")
	hero.tick_combat(1)
	var boss=dungeon.floor_generator._create_guard()
	boss.is_boss=true
	dungeon.floor_generator.content.add_child(boss)
	boss.set_physics_process(false)
	boss.position=hero.position+Vector3.FORWARD
	check(hero.request_attack(),"Devourer can attack after normal recovery")
	hero.tick_combat(0.11)
	var boss_damage: int=hero.get_current_attack_damage()
	hero._on_weapon_hitbox_area_entered(boss.get_node("Hurtbox"))
	print("HERO_QA boss hp=",boss.current_hp," resolved=",hero.weapon_hitbox.last_resolved_damage," swallowed=",hero.weapon_hitbox.last_swallowed," combo=",hero.combo_step)
	check(boss_damage>0 and boss_damage<60 and boss.current_hp==60-boss_damage and hero.weapon_hitbox.last_resolved_damage==boss_damage and not hero.weapon_hitbox.last_swallowed,"Boss receives ordinary combo damage and no swallow cue")
	hero.tick_combat(1)
	var snapshot=Data.capture(state,dungeon)
	check(Data.validate(snapshot) and snapshot.inventories.size()==5 and snapshot.secret_unlocked,"Schema three snapshot validates all five inventories and unlock")
	dungeon.start_saving(path)
	check(dungeon.save_session.flush()==OK,"Fresh isolated schema three save flushes")
	dungeon.queue_free()
	await get_tree().process_frame
	state.reset()
	dungeon=load("res://scenes/dungeon/dungeon_manager.tscn").instantiate()
	add_child(dungeon)
	dungeon.start_saving(path)
	hero=dungeon.get_node("MeleeHero")
	hero.set_physics_process(false)
	check(state.secret_unlocked and state.active_character_id=="devourer" and state.character_inventories.size()==5 and hero.weapon_inventory.get_weapons().is_empty(),"Scene restart preserves unlock, active secret and empty fifth inventory")
	await capture("restored-devourer")
	print("HERO_QA COMPLETE failures="+str(failures))

	if not OS.has_feature("android"): get_tree().quit(1 if failures else 0)
