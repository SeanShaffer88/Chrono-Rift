extends "res://tests/test_harness_template.gd"
const Services = preload("res://scripts/utilities/services.gd")
const Companion = preload("res://scenes/dungeon/collector_companion.gd")
const Orb = preload("res://scenes/dungeon/atla_sphere.gd")
const Healing = preload("res://scenes/dungeon/healing_pickup.gd")
const Pickup = preload("res://scenes/dungeon/dungeon_pickup.gd")
const Floor = preload("res://scenes/dungeon/floor_generator.gd")
const Menu = preload("res://scenes/ui/character_menu.gd")

class ResolverProbe extends Node3D:
	var box: Area3D
	var source: Node
	var area := Area3D.new()
	var is_boss := false
	var calls := 0
	var hits := 0
	func get_swallow_damage(_ordinary: int) -> int:
		calls+=1
		box.try_swallow(area,source,15)
		return 60
	func receive_hit(_amount: int,_source: Node) -> bool:
		hits+=1
		return true

func run_assertions() -> void:
	var state := Services.game_state()
	state.reset()
	var hero = load("res://scenes/characters/melee_hero.tscn").instantiate()
	root.add_child(hero)
	hero.set_physics_process(false)
	hero.position = Vector3(10, 0.1, 10)
	hero.current_hp = 47
	var original_position: Vector3 = hero.position
	var adventurer: Node = hero.weapon_inventory
	check(not state.swap_character("unknown"), "Unknown character cannot change session state")
	check(hero.request_attack(), "Initial character can attack immediately")
	hero.tick_combat(0.11)
	check(hero.hitbox_active, "Original attack reaches active frames")
	check(state.swap_character("swordsman"), "Swordsman can be selected")
	check(hero.character_id == "swordsman" and hero.weapon_inventory.equipped_weapon.weapon_id == "duskblade", "Selection binds correct identity and weapon")
	check(not hero.is_attacking() and not hero.hitbox_active, "Switching cancels pending damage")
	check(hero.current_hp == 47 and hero.position == original_position, "Switch preserves health and position")
	check(hero.get_node("Visual/LongHair").visible and not hero.get_node("Visual/Scarf").visible, "Swordsman has distinct hair and clothing")
	var sword = hero.weapon_inventory.equipped_weapon
	sword.apply_degradation(7.0)
	check(state.swap_character("riftwarden"), "Riftwarden can be selected")
	check(hero.get_node("Visual/Mask").visible and hero.get_node("Visual/Cape-1").visible, "Warden has mask and cape")
	check(hero.weapon_inventory.equipped_weapon.weapon_id == "rift_chain", "Warden starts with Crescent Chain")
	var blade: MeshInstance3D = hero.get_node("Visual/WeaponPivot/Blade")
	check(blade.mesh == null and blade.get_node("ChainBlade").visible, "Chain and curved blade replace straight weapon")
	check(hero.request_attack(), "Warden uses shared melee combat")
	adventurer.equip(null)
	check(hero.is_attacking(), "Inactive inventory cannot cancel active character's combat")
	state.swap_character("swordsman")
	check(hero.weapon_inventory.equipped_weapon == sword and sword.current_durability == 53.0, "Switching retains owned weapon and wear")
	check(state.swap_character("battlemage"), "Battlemage can be selected")
	check(hero.weapon_inventory.equipped_weapon.weapon_id == "battlemage_staff", "Battlemage owns its protected melee staff")
	check(hero.get_node("Visual/MageHat").visible and not hero.get_node("Visual/Hair").visible, "Battlemage owns its hat and hides ordinary hair")
	check(hero.request_attack(), "Battlemage uses existing melee attack")
	hero.tick_combat(1.0)
	var layer := CanvasLayer.new()
	root.add_child(layer)
	var menu := Menu.new()
	menu.hero = hero
	layer.add_child(menu)
	check(not menu.select_character("melee_hero"), "Closed menu cannot switch characters")
	menu.open_menu()
	check(paused and menu.opened, "Character menu pauses gameplay")
	check(menu.select_character("riftwarden") and not paused, "Choosing a character resumes gameplay")
	menu.open_menu()
	check(not menu.select_character("unknown") and menu.opened, "Invalid selection leaves menu open without mutation")
	menu.close_menu()
	hero.current_hp = 0
	menu.open_menu()
	check(not menu.opened, "Dead character cannot open switching menu")
	hero.current_hp = 100
	state.reset()
	check(hero.character_id == "melee_hero" and hero.weapon_inventory == state.weapon_inventory, "Session reset rebinds active hero to starter inventory")
	check(state.character_inventories.size() == 5, "Reset retains five owned inventories including empty locked secret")
	check(not state.is_character_available("devourer") and not state.swap_character("devourer"), "Secret availability blocks direct selection before unlock")
	state.record_floor_clear(5)
	check(not state.secret_unlocked, "Floor five clear cannot unlock secret")
	state.record_floor_clear(6)
	state.record_floor_clear(6)
	check(state.secret_unlocked and state.swap_character("devourer"), "Floor six clear unlocks idempotently")
	check(hero.weapon_inventory.get_weapons().is_empty() and hero.weapon_inventory.equipped_weapon==null, "Devourer owns no hidden weapon")
	check(hero.weapon_inventory.add_weapon(preload("res://data/weapons/trail_sword.tres"))==null and not hero.weapon_inventory.equip(sword), "Weaponless inventory rejects storing and equipping weapons")
	check(hero.get_node("Visual/DevourerArt").visible and not hero.get_node("Visual/Head").visible and not blade.visible, "Devourer hides humanoid and weapon geometry")
	var hud := preload("res://scenes/ui/adventure_hud.gd").new()
	hud.hero=hero
	root.add_child(hud)
	hud._process(0)
	check(not hud.whp.visible and not hud.caption.text.contains("WHP"),"Devourer HUD contains no durability bar or caption")
	check(hero.request_attack() and hero.get_current_attack_damage()==15, "Weaponless attack uses unchanged starter-balanced shared combo")
	hero.tick_combat(0.11)
	var enemy_factory := Floor.new()
	var target := enemy_factory._create_guard()
	root.add_child(target)
	target.set_physics_process(false)
	target.position=hero.position+Vector3(0,0,-1)
	var hurt: Area3D=target.get_node("Hurtbox")
	hurt.set_script(preload("res://scripts/combat/hurtbox_3d.gd"))
	hurt.iframe_duration=0.2
	hurt._iframe_left=0.1
	check(hero.weapon_hitbox.try_swallow(hurt,hero,15)==null and target.current_hp==60, "Swallow respects hurtbox invulnerability and permits later retry")
	hurt._iframe_left=0
	check(hero.weapon_hitbox.try_swallow(hurt,hero,15)==target and target.current_hp==0 and hero.weapon_hitbox.last_resolved_damage==60, "Accepted normal swallow uses lethal remaining HP through normal death pipeline")
	check(hero.weapon_hitbox.try_swallow(hurt,hero,15)==null, "One active window cannot acknowledge the same enemy twice")
	target.queue_free()
	var boss := enemy_factory._create_guard()
	boss.is_boss=true
	root.add_child(boss)
	boss.set_physics_process(false)
	boss.position=hero.position+Vector3(0,0,-1)
	check(hero.weapon_hitbox.try_swallow(boss.get_node("Hurtbox"),hero,15)==boss and boss.current_hp==45 and not hero.weapon_hitbox.last_swallowed, "Explicit boss receives ordinary damage without swallow cue")
	boss.queue_free()
	var probe := ResolverProbe.new()
	probe.box=hero.weapon_hitbox
	probe.source=hero
	probe.add_child(probe.area)
	root.add_child(probe)
	probe.position=hero.position+Vector3(0,0,-1)
	check(hero.weapon_hitbox.try_swallow(probe.area,hero,15)==probe and probe.calls==1 and probe.hits==1,"Resolver reentry cannot recurse or acknowledge duplicate swallow")
	probe.queue_free()

	enemy_factory.free()
	hero.tick_combat(1)
	state.swap_character("melee_hero")
	check(not hero.get_node("Visual/Body").visible and not hero.get_node("Visual/Face").visible and hero.get_node("Visual/Head").visible,"Secret-to-normal swap keeps legacy placeholders hidden")
	state.swap_character("swordsman")
	hud._process(0)
	check(hud.whp.visible and hud.caption.text.contains("WHP"),"Ordinary hero restores equipment HUD")
	hud.queue_free()
	check(not hero.get_node("Visual/Body").visible and not hero.get_node("Visual/Face").visible,"Normal-to-normal swap keeps legacy placeholders hidden")
	check(state.secret_unlocked, "Switching cannot relock unlocked secret")
	state.reset()
	check(not state.secret_unlocked, "New game reset relocks secret")
	var companion := Companion.new()
	companion.hero = hero
	root.add_child(companion)
	companion.set_physics_process(false)
	var pickup_position: Vector3 = hero.position + Vector3(2.5, 0, 0)
	var town_part := Orb.new()
	town_part.orb_id = "companion:town"
	town_part.piece_id = "tree"
	town_part.position = pickup_position
	root.add_child(town_part)
	check(companion.scan_pickups() == 1 and state.has_collected_orb(town_part.orb_id), "Companion collects town parts at full HP")
	check(companion.scan_pickups() == 0, "Queued pickup cannot be collected twice")
	var healing := Healing.new()
	healing.position = pickup_position
	root.add_child(healing)
	check(companion.scan_pickups() == 0 and not healing.collected, "Full health leaves healing pickup available")
	hero.current_hp = 95
	check(companion.scan_pickups() == 1 and hero.current_hp == 100, "Healing pickup restores only up to max HP")
	var floor := Floor.new()
	root.add_child(floor)
	floor.generate(1337, 1, false)
	var key := Pickup.new()
	key.floor_owner = floor
	key.position = pickup_position
	root.add_child(key)
	check(companion.scan_pickups() == 0 and not floor.key_collected, "Living guard blocks automatic key collection")
	floor.guard_defeated = true
	check(companion.scan_pickups() == 1 and floor.key_collected, "Defeated guard permits automatic key collection")
	var exit := Pickup.new()
	exit.kind = Pickup.Kind.EXIT
	exit.floor_owner = floor
	exit.position = pickup_position
	root.add_child(exit)
	check(companion.scan_pickups() == 0 and not floor.cleared, "Companion never triggers exits")
	check(not exit.try_companion_collect(hero), "Exit rejects direct companion collection too")
	var blocked := Orb.new()
	blocked.orb_id = "companion:blocked"
	blocked.piece_id = "path"
	blocked.position = pickup_position
	root.add_child(blocked)
	var wall := StaticBody3D.new()
	wall.collision_layer = 1
	wall.position = hero.position + Vector3(1.25, 0.8, 0)
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.3, 2, 2)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	wall.add_child(collision)
	root.add_child(wall)
	await physics_frame
	await physics_frame
	check(not companion.can_reach(blocked) and companion.scan_pickups() == 0, "Wall occlusion prevents remote collection")
	wall.free()
	await physics_frame
	check(companion.scan_pickups() == 1, "Clear path restores collection")
	var distant := Orb.new()
	distant.orb_id = "companion:distant"
	distant.piece_id = "river"
	distant.position = hero.position + Vector3(8, 0, 0)
	root.add_child(distant)
	check(not companion.can_reach(distant), "Companion respects collection radius")
	var other_world := SubViewport.new()
	other_world.own_world_3d = true
	root.add_child(other_world)
	var other_pickup := Orb.new()
	other_pickup.orb_id = "companion:other-world"
	other_pickup.piece_id = "bridge"
	other_pickup.position = pickup_position
	other_world.add_child(other_pickup)
	check(not companion.can_reach(other_pickup), "Companion cannot collect across town/dungeon worlds")
	hero.current_hp = 0
	check(not companion.can_reach(distant), "Dead player cannot collect items remotely")
	other_world.free()
	distant.free()
	exit.free()
	floor.free()
	companion.free()
	layer.free()
	hero.free()
	state.reset()
	var dungeon = load("res://scenes/dungeon/dungeon_manager.tscn").instantiate()
	root.add_child(dungeon)
	dungeon.open_town()
	var town_menu: Node = null
	for child: Node in dungeon.town_view._ui.get_children():
		if child.has_method("open_menu"):
			town_menu = child
	town_menu.open_menu()
	var viewport: SubViewport = dungeon.town_view.get_viewport()
	check(paused and viewport.get_parent().can_process(), "Town viewport container forwards input while menu pauses the tree")
	check(not dungeon.town_view.can_process() and town_menu.can_process(), "Town simulation pauses while its character menu remains interactive")
	check(town_menu.select_character("riftwarden"), "Town menu switches the character")
	dungeon.close_town()
	check(not paused and dungeon.get_node("MeleeHero").character_id == "riftwarden", "Returning from town retains character and resumes dungeon")
	dungeon.free()
	await process_frame
	state.reset()
