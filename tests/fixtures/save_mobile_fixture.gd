extends Node
## Isolated Android cold-start QA: driver backgrounds/kills/relaunches this app.
const Data = preload("res://scripts/persistence/save_data.gd")
const Grid = preload("res://scenes/georama/town_grid.gd")
const PATH := "user://save-qa.json"
const PHASE := "user://save-qa-phase.txt"
var dungeon: Node

func _ready() -> void:
	_run.call_deferred()

func _check(value: bool, text: String) -> void:
	if not value:
		push_error("SAVE_QA FAIL: " + text)
		get_tree().quit(1)
	else:
		print("SAVE_QA PASS: " + text)

func _mark(phase: String) -> void:
	var file := FileAccess.open(PHASE, FileAccess.WRITE)
	file.store_string(phase)
	file.close()

func _run() -> void:
	dungeon = load("res://scenes/dungeon/dungeon_manager.tscn").instantiate()
	add_child(dungeon)
	dungeon.start_saving(PATH)
	var phase := FileAccess.get_file_as_string(PHASE) if FileAccess.file_exists(PHASE) else ""
	var state := get_node("/root/GameState")
	if phase.is_empty():
		dungeon.floor_number = 4
		dungeon.dungeon_seed = 981
		dungeon._load_floor()
		state.swap_character("riftwarden")
		var weapon: Resource = state.weapon_inventory.equipped_weapon
		weapon.base_attack = 31
		weapon.elemental_stats[2] = 9
		weapon.slayer_stats[3] = 7
		weapon.apply_degradation(999)
		state.weapon_inventory.add_weapon(preload("res://data/weapons/gladius.tres")).apply_degradation(13)
		for part in Grid.PARTS:
			state.collect_restoration_orb("save-qa:" + part, part)
		var grid := Grid.new()
		grid.bind_session(state)
		for slot in grid.catalog.mayor_house.slots:
			grid.assemble("save-qa:mayor_house", slot, "save-qa:" + grid.catalog.mayor_house.slots[slot])
		grid.place("save-qa:mayor_house", Vector2i(28, 30), 1)
		grid.talk("save-qa:mayor_house")
		var hero: Node3D = dungeon.get_node("MeleeHero")
		dungeon.floor_generator.guard.receive_hit(999, hero)
		dungeon.floor_generator.try_collect_key(hero)
		hero.current_hp = 67
		for child: Node in dungeon.floor_generator.content.get_children():
			if child.get_script() == preload("res://scenes/dungeon/healing_pickup.gd"):
				child.try_companion_collect(hero)
				break
		hero.current_hp = 67
		dungeon.open_town()
		dungeon.town_view.set_editing(false)
		var town_hero: Node3D = dungeon.town_view.get_node("MeleeHero")
		town_hero.position = Vector3(61.25, 0.1, 69.5)
		town_hero.current_hp = 88
		_check(Data.validate(Data.capture(state, dungeon)), "seeded Android snapshot validates")
		_mark("town")
		# Let the first rendered frame finish before the driver backgrounds the app.
		await get_tree().create_timer(1.0).timeout
		print("SAVE_QA READY: background-town")
	elif phase == "town":
		_check(state.active_character_id == "riftwarden", "active character survived process restart")
		var weapon: Resource = state.weapon_inventory.equipped_weapon
		_check(weapon.is_broken and not weapon.destroy_on_break and weapon.base_attack == 31, "protected broken weapon and trained attack restored")
		_check(weapon.elemental_stats[2] == 9 and weapon.slayer_stats[3] == 7, "integer-key stats restored from JSON")
		_check(state.weapon_inventory.get_weapons()[1].current_durability == 67, "other weapon wear restored")
		_check(is_instance_valid(dungeon.town_view) and not dungeon.town_view.editing, "town walking mode resumed")
		var hero: Node3D = dungeon.town_view.get_node("MeleeHero")
		_check(absf(hero.position.x - 61.25) < 0.001 and absf(hero.position.z - 69.5) < 0.001 and hero.current_hp == 88, "last town position and HP restored")
		_check(state.town_objects["save-qa:mayor_house"].rotation == 1 and state.town_objects["save-qa:mayor_house"].requests_known, "town assembly placement and resident dialogue restored")
		dungeon.close_town()
		_check(dungeon.floor_number == 4 and dungeon.get_node("MeleeHero").current_hp == 67, "saved dungeon and health retained behind town")
		_check(dungeon.floor_generator.guard_defeated and dungeon.floor_generator.key_collected, "guard and key stay resolved")
		_check(dungeon.floor_generator.collected_healing.size() == 1, "consumed healing remains tracked")
		_mark("dungeon")
		await get_tree().create_timer(1.0).timeout
		print("SAVE_QA READY: background-dungeon")
	elif phase == "dungeon":
		_check(not is_instance_valid(dungeon.town_view) and dungeon.floor_number == 4, "dungeon mode survived second process restart")
		_check(dungeon.get_node("MeleeHero").current_hp == 67 and dungeon.floor_generator.key_collected, "dungeon HP and progression survived")
		_check(dungeon.save_session.flush() == OK, "valid backup is committed before corruption exercise")
		# QA-only: block writes before simulating a corrupt primary; preserve backup.
		dungeon.save_session._loaded = false
		var file := FileAccess.open(PATH, FileAccess.WRITE)
		file.store_string("interrupted-primary")
		file.close()
		_mark("recovery")
		print("SAVE_QA READY: corrupt-primary")
	elif phase == "recovery":
		_check(dungeon.save_session.status.contains("Recovered"), "cold startup recovered validated backup")
		_check(state.active_character_id == "riftwarden" and dungeon.floor_number == 4 and dungeon.floor_generator.key_collected, "backup preserved owned progress")
		_check(dungeon.save_session.flush() == OK, "recovered game can write a valid new primary")
		print("SAVE_QA COMPLETE")
