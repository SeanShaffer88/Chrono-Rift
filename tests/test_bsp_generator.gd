extends "res://tests/test_harness_template.gd"

const BSP := preload("res://scripts/utilities/bsp_tree.gd")
const Floor := preload("res://scenes/dungeon/floor_generator.gd")
const Orb := preload("res://scenes/dungeon/atla_sphere.gd")
const Factory := preload("res://scripts/utilities/primitive_mesh_factory.gd")

func run_assertions() -> void:
	_test_layouts()
	_test_materials()
	await _test_collection()
	await _test_floor_progression()
	await _test_manager()

func _signature(floor: Node) -> String:
	var cells: Array = floor.layout.walkable.keys()
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	return str([cells, floor.layout.rooms, floor.spawn_cell, floor.exit_cell, floor.key_cell, floor.orb_cells])

func _test_layouts() -> void:
	var generator := Floor.new()
	var signatures: Dictionary = {}
	for seed_value in [0, 1, 2, 3, 17, 42, 1337, 10007, -77, 2147483647]:
		check(generator.generate(seed_value, 1, false), "seed %d generates a floor" % seed_value)
		var layout: RefCounted = generator.layout
		var distances: Dictionary = layout.distances_from(generator.spawn_cell)
		check(distances.size() == layout.walkable.size(), "seed %d: every carved cell is reachable" % seed_value)
		check(generator.spawn_cell == layout.rooms[0].get_center(), "seed %d: spawn uses first BSP leaf" % seed_value)
		var farthest := 0
		for room: Rect2i in layout.rooms:
			farthest = maxi(farthest, distances[room.get_center()])
		check(distances[generator.exit_cell] == farthest, "seed %d: exit is farthest room by traversable distance" % seed_value)
		check(generator.key_cell != generator.spawn_cell and generator.key_cell != generator.exit_cell and layout.distances_from(generator.key_cell).has(generator.exit_cell), "seed %d: distinct key is reachable before exit" % seed_value)
		var occupied := {generator.spawn_cell: true, generator.exit_cell: true, generator.key_cell: true, generator.guard_cell: true}
		var valid: bool = layout.walkable.has(generator.guard_cell) and generator.orb_cells.size() == 3
		for cell: Vector2i in generator.orb_cells:
			valid = valid and distances.has(cell) and not occupied.has(cell)
			occupied[cell] = true
		check(valid, "seed %d: guard and three distinct orbs occupy reachable cells" % seed_value)
		var enclosed := true
		for cell: Vector2i in layout.walkable:
			enclosed = enclosed and cell.x > 0 and cell.y > 0 and cell.x < 47 and cell.y < 47
		check(enclosed, "seed %d: outer border stays solid" % seed_value)
		var signature := _signature(generator)
		signatures[signature] = true
		generator.generate(seed_value, 1, false)
		check(_signature(generator) == signature, "seed %d: layout and placements repeat exactly" % seed_value)
	check(signatures.size() == 10, "different seeds produce different layouts")
	var before := _signature(generator)
	generator.grid_size = Vector2i(8, 8)
	check(not generator.generate(99, 1, false) and _signature(generator) == before, "invalid grid leaves previous layout intact")
	generator.grid_size = Vector2i(48, 48)
	check(not generator.generate(99, 0, false) and _signature(generator) == before, "invalid floor number leaves previous layout intact")
	check(generator.layout.distances_from(Vector2i(-1, -1)).is_empty(), "path search rejects a non-walkable starting cell")
	for grid_size in [Vector2i(24, 24), Vector2i(32, 64), Vector2i(64, 32), Vector2i(128, 128)]:
		var layout := BSP.new()
		check(layout.generate(42, grid_size) and layout.distances_from(layout.rooms[0].get_center()).size() == layout.walkable.size(), "supported grid %s remains connected" % grid_size)
	generator.free()

func _test_materials() -> void:
	var first := Factory.create_box(Vector3.ONE, Color.SLATE_GRAY)
	var second := Factory.create_box(Vector3.ONE, Color.SLATE_GRAY)
	check(first.material_override == second.material_override, "matching primitive looks share a cached material")
	check(first.mesh.surface_get_material(0) == null, "primitive mesh has no embedded material")
	var glowing := Factory.get_shared_material(Color.SLATE_GRAY, 0.9, 1.0)
	check(glowing != first.material_override and glowing.emission_enabled, "emission participates in the material cache key")
	first.free()
	second.free()

func _test_collection() -> void:
	var state := root.get_node("GameState")
	state.reset()
	var bus := root.get_node("EventBus")
	var events: Array[Array] = []
	var callback := func(id: String, piece: String) -> void: events.append([id, piece])
	bus.atla_collected.connect(callback)
	check(not state.collect_restoration_orb("", "cottage") and not state.collect_restoration_orb("orb", ""), "collection rejects missing orb and piece IDs")
	var hero: Variant = load("res://scenes/characters/melee_hero.tscn").instantiate()
	root.add_child(hero)
	hero.set_physics_process(false)
	hero.position = Vector3(100, 0, 100)
	var npc := Node3D.new()
	root.add_child(npc)
	var orb := Orb.new()
	orb.orb_id = "regression-orb"
	orb.piece_id = "cottage"
	root.add_child(orb)
	check(not orb.try_collect(npc) and not orb.try_collect(null), "non-player and null bodies cannot collect")
	hero.is_player = false
	check(not orb.try_collect(hero), "non-player character cannot collect an orb")
	hero.is_player = true
	hero.add_to_group(&"players")
	var hp: int = hero.current_hp
	hero.current_hp = 0
	check(not orb.try_collect(hero), "dead player cannot collect")
	hero.current_hp = hp
	# The real physics callback, not a direct handler call, performs collection.
	hero.position = Vector3.ZERO
	for frame in 5:
		await physics_frame
	await process_frame
	check(not is_instance_valid(orb) and state.has_atla("cottage") and state.has_collected_orb("regression-orb"), "physics overlap collects a restoration orb into GameState")
	check(events == [["regression-orb", "cottage"]], "physical collection emits its ID and piece once")
	check(not state.collect_restoration_orb("regression-orb", "bridge") and state.atla_inventory.size() == 1, "repeated orb ID cannot grant a second or different piece")
	check(state.collect_restoration_orb("second-orb", "cottage") and state.atla_inventory.size() == 2, "different orbs may contain separate copies of the same piece type")
	var duplicate := Orb.new()
	duplicate.orb_id = "regression-orb"
	duplicate.piece_id = "cottage"
	root.add_child(duplicate)
	await process_frame
	check(not is_instance_valid(duplicate) and events.size() == 2, "already-collected orb disappears on reload without another event")
	bus.atla_collected.disconnect(callback)
	hero.queue_free()
	npc.queue_free()
	await process_frame
	state.reset()
	check(state.collected_orb_ids.is_empty() and state.atla_inventory.is_empty(), "new-game reset clears orb IDs and restoration inventory")

func _test_floor_progression() -> void:
	var floor := Floor.new()
	root.add_child(floor)
	check(floor.generate(42), "runtime floor builds geometry, key, guard and orbs")
	var original_content: Node3D = floor.content
	var hero: Variant = load("res://scenes/characters/melee_hero.tscn").instantiate()
	root.add_child(hero)
	hero.set_physics_process(false)
	hero.position = floor.cell_to_world(floor.spawn_cell)
	await physics_frame
	await physics_frame
	var space := floor.get_world_3d().direct_space_state
	for direction: Vector2i in BSP.DIRECTIONS:
		var neighbor: Vector2i = floor.spawn_cell + direction
		if floor.layout.walkable.has(neighbor):
			var query := PhysicsRayQueryParameters3D.create(floor.cell_to_world(floor.spawn_cell) + Vector3.UP, floor.cell_to_world(neighbor) + Vector3.UP, 1)
			check(space.intersect_ray(query).is_empty(), "adjacent walkable cells have no intervening wall collider")
			break
	var found_wall := false
	for cell: Vector2i in floor.layout.walkable:
		for direction: Vector2i in BSP.DIRECTIONS:
			var neighbor := cell + direction
			if not floor.layout.walkable.has(neighbor):
				var query := PhysicsRayQueryParameters3D.create(floor.cell_to_world(cell) + Vector3.UP, floor.cell_to_world(neighbor) + Vector3.UP, 1)
				found_wall = not space.intersect_ray(query).is_empty()
				break
		if found_wall:
			break
	check(found_wall, "visible wall boundary has a matching solid physics collider")
	var bus := root.get_node("EventBus")
	var events: Array[String] = []
	var unlocked := func() -> void: events.append("key")
	var cleared := func() -> void: events.append("exit")
	bus.dungeon_gate_unlocked.connect(unlocked)
	bus.floor_cleared.connect(cleared)
	check(not floor.try_exit(hero), "exit refuses a player without the key")
	check(not floor.try_collect_key(hero), "living guard protects the key")
	floor.guard.receive_hit(60, hero)
	check(floor.guard_defeated and floor.try_collect_key(hero), "defeating guard allows key collection")
	check(not floor.try_collect_key(hero) and events == ["key"], "key unlock event fires once")
	check(floor.try_exit(hero) and not floor.try_exit(hero) and events == ["key", "exit"], "key unlocks exit and floor-clear event fires once")
	var state := root.get_node("GameState")
	state.collect_restoration_orb(floor.get_orb_id(0), "mayor_house")
	check(floor.generate(42) and not is_instance_valid(original_content), "regeneration frees previous geometry and triggers")
	check(not floor.key_collected and not floor.cleared and not floor.guard_defeated, "regeneration resets key, guard and exit state")
	check(floor.content.get_node_or_null("RestorationOrb0") == null and floor.content.get_node_or_null("RestorationOrb1") != null, "regeneration skips previously collected orbs")
	check(floor.content.get_node("ExitGate").collision_layer == 128, "interactables use layer eight")
	var batches := floor.content.find_children("*", "MultiMeshInstance3D", true, false)
	check(not batches.is_empty() and batches.size() <= 10, "dungeon art stays within ten geometry batches")
	var old_id: String = floor.get_orb_id(0)
	floor.generate(42, 2, false)
	check(floor.get_orb_id(0) != old_id and state.has_atla("mayor_house"), "floor IDs differ while collected pieces survive transitions")
	bus.dungeon_gate_unlocked.disconnect(unlocked)
	bus.floor_cleared.disconnect(cleared)
	hero.queue_free()
	floor.queue_free()
	await process_frame
	state.reset()

func _test_manager() -> void:
	var manager: Variant = load("res://scenes/dungeon/dungeon_manager.tscn").instantiate()
	root.add_child(manager)
	var hero: Variant = manager.get_node("MeleeHero")
	hero.set_physics_process(false)
	check(hero.position.is_equal_approx(manager.floor_generator.cell_to_world(manager.floor_generator.spawn_cell) + Vector3.UP * 0.1), "dungeon startup positions the hero on generated spawn")
	check(manager.get_node_or_null("TouchUI/VirtualJoystick") != null and manager.get_node_or_null("TouchUI/AttackButton") != null, "dungeon reuses existing touch controls")
	var weapon: Resource = root.get_node("GameState").weapon_inventory.equipped_weapon
	manager.floor_generator.guard.receive_hit(60, hero)
	manager.floor_generator.try_collect_key(hero)
	hero.position = manager.floor_generator.cell_to_world(manager.floor_generator.exit_cell)
	for frame in 5:
		await physics_frame
	await process_frame
	await process_frame
	check(manager.floor_number == 2 and not manager.floor_generator.key_collected, "exit schedules the next generated floor outside physics callbacks")
	check(root.get_node("GameState").weapon_inventory.equipped_weapon == weapon, "floor transition preserves weapon ownership and durability")
	manager.queue_free()
	await process_frame
