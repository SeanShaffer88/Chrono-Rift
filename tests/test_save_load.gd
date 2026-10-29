extends "res://tests/test_harness_template.gd"
const Data = preload("res://scripts/persistence/save_data.gd")
const Store = preload("res://scripts/persistence/save_store.gd")
const Services = preload("res://scripts/utilities/services.gd")
const Grid = preload("res://scenes/georama/town_grid.gd")
var path := "user://verification-save-%d.json" % OS.get_process_id()

func _write(file_path: String, text: String) -> void:
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	file.store_string(text)
	file.close()

func run_assertions() -> void:
	var state := Services.game_state()
	state.reset()
	var dungeon: Variant = load("res://scenes/dungeon/dungeon_manager.tscn").instantiate()
	root.add_child(dungeon)
	await physics_frame
	check(dungeon.save_session == null, "Test scenes never load or overwrite the user's autosave")
	dungeon.floor_number = 4
	dungeon.dungeon_seed = 981
	dungeon._load_floor()
	state.swap_character("riftwarden")
	var inventory: Node = state.weapon_inventory
	var starter: Resource = inventory.equipped_weapon
	starter.base_attack = 29
	starter.elemental_stats[1] = 8
	starter.slayer_stats[2] = 4
	starter.apply_degradation(999)
	var evolved: Resource = inventory.add_weapon(preload("res://data/weapons/gladius.tres"))
	evolved.apply_degradation(11)
	state.thirst = 42.5
	for part in ["mayor_house", "mayor_roof", "mayor_door", "mayor_bed", "mayor_stove", "mayor_resident"]:
		state.collect_restoration_orb("save:" + part, part)
	var grid := Grid.new()
	grid.bind_session(state)
	for slot in grid.catalog.mayor_house.slots:
		grid.assemble("save:mayor_house", slot, "save:" + grid.catalog.mayor_house.slots[slot])
	grid.place("save:mayor_house", Vector2i(28, 30), 1)
	grid.talk("save:mayor_house")
	var hero: Node3D = dungeon.get_node("MeleeHero")
	hero.position = dungeon.floor_generator.cell_to_world(dungeon.floor_generator.spawn_cell) + Vector3(0.2, 0.1, 0.2)
	hero.current_hp = 67
	dungeon.floor_generator.guard.receive_hit(15, hero)
	var healing: Node
	for child: Node in dungeon.floor_generator.content.get_children():
		if child.get_script() == preload("res://scenes/dungeon/healing_pickup.gd"):
			healing = child
			break
	check(healing != null and healing.try_companion_collect(hero), "Real healing pickup records its collection")
	hero.current_hp = 67
	var data: Dictionary = JSON.parse_string(JSON.stringify(Data.capture(state, dungeon)))
	check(Data.validate(data), "Full JSON round trip validates inventories, multipart town and floor progress")
	var store := Store.new(path, Data.validate)
	check(store.read_save().status == "missing", "Missing save starts a new session")
	check(store.write_save(data) == OK and FileAccess.file_exists(path + ".bak"), "First durable write creates a recovery backup")
	var second := data.duplicate(true)
	second.hero.hp = 55
	check(store.write_save(second) == OK and store.read_save().data.hero.hp == 55, "Atomic replacement succeeds when primary and backup already exist")
	var envelope: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	envelope.payload = envelope.payload.replace('"hp":55', '"hp":54')
	_write(path, JSON.stringify(envelope))
	check(store.read_save().status == "recovered", "Checksum detects valid JSON whose payload was damaged")
	check(store.write_save(second) == OK, "Primary repair succeeds after checksum recovery")
	_write(path + ".tmp", "interrupted write")
	check(store.read_save().data.hero.hp == 55, "Interrupted temporary write cannot replace committed progress")
	_write(path, "truncated")
	var recovered: Dictionary = store.read_save()
	check(recovered.status == "recovered" and recovered.data.hero.hp == 67, "Corrupt primary recovers the previous valid snapshot")
	check(store.write_save(second) == OK, "Recovered session can save without copying corrupt primary over backup")
	_write(path, "truncated again")
	check(store.read_save().data.hero.hp == 67, "Recovery backup remains valid after repairing primary")
	_write(path, JSON.stringify({"version": 999}))
	check(store.read_save().status == "unsupported" and store.write_save(data) != OK, "Newer save schema is preserved rather than overwritten or rolled back")
	check(JSON.parse_string(FileAccess.get_file_as_string(path)).version == 999, "Blocked save leaves original bytes intact")
	_write(path, "bad")
	_write(path + ".bak", "bad")
	check(store.read_save().status == "invalid" and store.write_save(data) != OK, "Two invalid copies preserve files and block autosave")
	var malformed := data.duplicate(true)
	malformed.inventories.riftwarden.weapons[0].id = "res://untrusted.gd"
	check(not Data.validate(malformed), "Save cannot load arbitrary resource paths")
	malformed = data.duplicate(true)
	malformed.inventories.riftwarden.equipped = 99
	check(not Data.validate(malformed), "Invalid equipped index is rejected")
	malformed = data.duplicate(true)
	malformed.thirst = INF
	check(not Data.validate(malformed), "Nonfinite numbers are rejected")
	malformed = data.duplicate(true)
	malformed.town["save:mayor_house"].components.Roof = "not owned"
	check(not Data.validate(malformed), "Unowned restoration components are rejected")
	malformed = data.duplicate(true)
	malformed.floor.key = true
	check(not Data.validate(malformed), "Locked guard/key invariant is validated")
	# Restore through the actual session owner after changing all live state.
	_write(path, "bad")
	DirAccess.remove_absolute(path + ".bak")
	store = Store.new(path, Data.validate)
	DirAccess.remove_absolute(path)
	check(store.write_save(data) == OK, "Valid test save is ready for actual scene restoration")
	state.reset()
	dungeon.start_saving(path)
	check(state.active_character_id == "riftwarden" and state.thirst == 42.5, "Active character and thirst restore")
	check(state.weapon_inventory.equipped_weapon.is_broken and not state.weapon_inventory.equipped_weapon.destroy_on_break, "Broken protected starter remains owned and equipped")
	check(state.weapon_inventory.equipped_weapon.base_attack == 29 and state.weapon_inventory.equipped_weapon.elemental_stats[1] == 8 and state.weapon_inventory.equipped_weapon.slayer_stats[2] == 4, "Trained attack and integer-key elemental/slayer stats restore")
	check(state.weapon_inventory.get_weapons()[1].current_durability == evolved.current_durability, "Other owned weapon wear restores independently")
	check(dungeon.floor_number == 4 and hero.current_hp == 67 and hero.position.is_equal_approx(Data.unpack_vector(data.hero.position)), "Floor, exact position and HP restore")
	check(dungeon.floor_generator.guard.current_hp == 45, "Partially damaged guard restores without free healing")
	var remaining := true
	for child: Node in dungeon.floor_generator.content.get_children():
		if child.get_script() == preload("res://scenes/dungeon/healing_pickup.gd") and data.floor.healing.has(child.pickup_id): remaining = false
	check(remaining, "Consumed healing cannot respawn after reload")
	check(state.town_objects["save:mayor_house"].cell == Vector2i(28, 30) and state.town_objects["save:mayor_house"].rotation == 1 and state.town_objects["save:mayor_house"].requests_known, "Placement, rotation, assembly and resident dialogue state restore")
	dungeon.floor_generator.guard.receive_hit(999, hero)
	dungeon.floor_generator.try_collect_key(hero)
	check(dungeon.save_session.flush() == OK, "Guard defeat and key can be saved")
	var cleared_data: Dictionary = Data.capture(state, dungeon)
	dungeon.floor_generator.generate(dungeon.floor_generator.floor_seed, 4)
	dungeon.floor_generator.restore_progress(cleared_data.floor)
	check(dungeon.floor_generator.guard_defeated and not dungeon.floor_generator.guard.is_alive() and not dungeon.floor_generator.content.has_node("GateKey"), "Defeated guard and collected key remain resolved")
	dungeon.open_town()
	dungeon.town_view.set_editing(false)
	var town_hero: Node3D = dungeon.town_view.get_node("MeleeHero")
	town_hero.position = Vector3(61.25, 0.1, 69.5)
	town_hero.current_hp = 88
	check(dungeon.save_session.flush() == OK, "Town visit saves while the dungeon is paused")
	dungeon.queue_free()
	await process_frame
	# Exercise real main-scene _ready, including a town viewport under the root.
	var template: Node = load("res://scenes/dungeon/dungeon_manager.tscn").instantiate()
	template.persistence_path = path
	var packed := PackedScene.new()
	check(packed.pack(template) == OK, "Isolated main-scene save fixture packs")
	template.floor_generator.free() # _ready never parented this eagerly created node.
	template.free()
	check(change_scene_to_packed(packed) == OK, "Actual main-scene startup begins without touching player files")
	await process_frame
	await process_frame
	dungeon = current_scene
	check(is_instance_valid(dungeon.town_view) and not dungeon.town_view.editing, "Cold session restore reopens town walking mode")
	var resumed_position: Vector3 = dungeon.town_view.get_node("MeleeHero").position
	check(absf(resumed_position.x - 61.25) < 0.001 and absf(resumed_position.z - 69.5) < 0.001 and resumed_position.y > -0.05 and resumed_position.y <= 0.101 and dungeon.town_view.get_node("MeleeHero").current_hp == 88, "Town position and HP survive session recreation with normal gravity")
	dungeon.close_town()
	await process_frame
	dungeon.get_node("MeleeHero").take_damage(999)
	check(dungeon.save_session.flush() == OK, "Defeat state saves instead of granting a free heal")
	dungeon.queue_free()
	await process_frame
	dungeon = load("res://scenes/dungeon/dungeon_manager.tscn").instantiate()
	root.add_child(dungeon)
	dungeon.start_saving(path)
	check(dungeon.get_node("MeleeHero").current_hp == 0 and dungeon.get_node("TouchUI/DefeatPanel").visible, "Reloaded defeat offers the existing Retry floor action")
	check(dungeon.retry_floor() and dungeon.get_node("MeleeHero").current_hp == 100, "Retry remains usable after restoring defeat")
	var permission_path := path + ".blocked"
	_write(permission_path, "not a directory")
	var unavailable := Store.new(permission_path + "/autosave.json", Data.validate)
	check(unavailable.write_save(data) != OK, "Filesystem failure reports an error without claiming a successful save")
	DirAccess.remove_absolute(permission_path)
	dungeon.queue_free()
	await process_frame
	state.reset()
	for suffix in ["", ".bak", ".tmp", ".bak.tmp"]:
		if FileAccess.file_exists(path + suffix): DirAccess.remove_absolute(path + suffix)
