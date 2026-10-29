extends Node3D

signal exit_reached
const Scenery = preload("res://scripts/utilities/scenery.gd")
const BSP := preload("res://scripts/utilities/bsp_tree.gd")
const Factory := preload("res://scripts/utilities/primitive_mesh_factory.gd")
const Orb := preload("res://scenes/dungeon/atla_sphere.gd")
const Pickup := preload("res://scenes/dungeon/dungeon_pickup.gd")
const Healing = preload("res://scenes/dungeon/healing_pickup.gd")
const Dummy := preload("res://scenes/characters/training_dummy.gd")
const Services := preload("res://scripts/utilities/services.gd")
const CELL_SIZE := 2.0
const TownGrid := preload("res://scenes/georama/town_grid.gd")
const PIECES := TownGrid.PARTS

@export var grid_size := Vector2i(48, 48)
@export_range(1, 20) var orb_count: int = 3
var layout := BSP.new()
var spawn_cell := Vector2i.ZERO
var exit_cell := Vector2i.ZERO
var key_cell := Vector2i.ZERO
var guard_cell := Vector2i.ZERO
var orb_cells: Array[Vector2i] = []
var floor_seed: int
var floor_number: int = 1
var key_collected := false
var guard_defeated := false
var cleared := false
var content: Node3D = null
var guard: Node3D = null

func generate(seed_value: int, number: int = 1, build_geometry: bool = true) -> bool:
	var candidate := BSP.new()
	if number < 1 or orb_count < 1 or orb_count > 20 or not candidate.generate(seed_value, grid_size):
		return false
	# Validate before replacing a playable floor.
	layout = candidate
	floor_seed = seed_value
	floor_number = number
	key_collected = false
	guard_defeated = false
	cleared = false
	spawn_cell = layout.rooms[0].get_center()
	var distances := layout.distances_from(spawn_cell)
	exit_cell = _farthest_room(distances, [spawn_cell])
	key_cell = _farthest_room(distances, [spawn_cell, exit_cell])
	guard_cell = key_cell + Vector2i.RIGHT
	orb_cells.clear()
	var reserved := [spawn_cell, exit_cell, key_cell, guard_cell]
	var available: Array[Vector2i] = []
	for cell: Vector2i in layout.walkable:
		if not reserved.has(cell) and cell.distance_squared_to(spawn_cell) >= 9:
			available.append(cell)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 719
	for index in mini(orb_count, available.size()):
		var pick := rng.randi_range(0, available.size() - 1)
		orb_cells.append(available[pick])
		available.remove_at(pick)
	if is_instance_valid(content):
		content.free()
	content = null
	guard = null
	if build_geometry:
		_build_content()
	return true

func _farthest_room(distances: Dictionary, excluded: Array) -> Vector2i:
	var best := spawn_cell
	var distance := -1
	for room: Rect2i in layout.rooms:
		var cell := room.get_center()
		if not excluded.has(cell) and int(distances.get(cell, -1)) > distance:
			best = cell
			distance = distances[cell]
	return best

func cell_to_world(cell: Vector2i) -> Vector3:
	return Vector3(cell.x * CELL_SIZE, 0.0, cell.y * CELL_SIZE)

func get_orb_id(index: int) -> String:
	return "%d:%d:%d" % [floor_seed, floor_number, index]

func _build_content() -> void:
	content = Node3D.new()
	content.name = "GeneratedFloor"
	var walls: Dictionary = {}
	for cell: Vector2i in layout.walkable:
		for direction: Vector2i in BSP.DIRECTIONS:
			var neighbor := cell + direction
			if not layout.walkable.has(neighbor):
				walls[neighbor] = true
	var flagstones: Array[Vector2i] = []
	for cell: Vector2i in layout.walkable:
		for offset in [Vector2i.ZERO, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.ONE]:
			flagstones.append(cell * 2 + offset)
	# Shift the half-size tiles so their outer edge still matches the collision floor.
	var paving := Factory.create_tile_batch(flagstones, Vector3(0.96, 0.2, 0.96), Color(0.34, 0.40, 0.46), 1.0, -0.1)
	paving.position = Vector3(-0.5, 0, -0.5)
	content.add_child(paving)
	for course in 3:
		content.add_child(Factory.create_tile_batch(walls.keys(), Vector3(1.97, 0.9, 1.97), Color(0.29, 0.37, 0.46), CELL_SIZE, 0.46 + course * 0.94))
	content.add_child(Factory.create_tile_batch(walls.keys(), Vector3(2.08, 0.16, 2.08), Color(0.39, 0.46, 0.53), CELL_SIZE, 2.84))
	content.add_child(Factory.create_tile_batch(walls.keys(), Vector3(2.04, 0.22, 2.04), Color(0.22, 0.30, 0.35), CELL_SIZE, 0.11))
	var solid := StaticBody3D.new()
	solid.collision_layer = 1
	solid.collision_mask = 0
	_add_collision(solid, Vector3(layout.size.x * CELL_SIZE, 0.2, layout.size.y * CELL_SIZE), Vector3((layout.size.x - 1) * CELL_SIZE / 2, -0.1, (layout.size.y - 1) * CELL_SIZE / 2))
	# Merge horizontal wall runs to keep collision node counts below tile counts.
	for y in layout.size.y:
		var x := 0
		while x < layout.size.x:
			if not walls.has(Vector2i(x, y)):
				x += 1
				continue
			var start := x
			while walls.has(Vector2i(x, y)):
				x += 1
			_add_collision(solid, Vector3((x - start) * CELL_SIZE, 2.8, CELL_SIZE), Vector3((start + x - 1) * CELL_SIZE / 2, 1.4, y * CELL_SIZE))
	content.add_child(solid)
	guard = _create_guard()
	guard.name = "KeyGuard"
	guard.position = cell_to_world(guard_cell)
	guard.hit_received.connect(_on_guard_hit)
	content.add_child(guard)
	for kind in [Pickup.Kind.KEY, Pickup.Kind.EXIT]:
		var trigger := Pickup.new()
		trigger.kind = kind
		trigger.floor_owner = self
		trigger.name = "GateKey" if kind == Pickup.Kind.KEY else "ExitGate"
		trigger.position = cell_to_world(key_cell if kind == Pickup.Kind.KEY else exit_cell)
		content.add_child(trigger)
	var state := Services.game_state()
	for index in orb_cells.size():
		var part_index := (floor_number - 1) * orb_count + index
		if part_index >= PIECES.size():
			continue
		if state and state.has_collected_orb(get_orb_id(index)):
			continue
		var orb := Orb.new()
		orb.orb_id = get_orb_id(index)
		orb.piece_id = PIECES[part_index]
		orb.name = "RestorationOrb%d" % index
		orb.position = cell_to_world(orb_cells[index])
		content.add_child(orb)
	for room: Rect2i in layout.rooms.slice(0, 3):
		var cell := room.get_center() + Vector2i.DOWN
		if not layout.walkable.has(cell) or cell in [spawn_cell, key_cell, guard_cell, exit_cell] or orb_cells.has(cell):
			continue
		var healing := Healing.new()
		healing.position = cell_to_world(cell)
		content.add_child(healing)
	for index in mini(4, layout.rooms.size()):
		var torch := Factory.create_box(Vector3(0.18, 0.34, 0.18), Color(1, 0.55, 0.12), 1.5)
		torch.position = cell_to_world(layout.rooms[index].position) + Vector3(0, 1.4, 0)
		content.add_child(torch)
		Scenery.add(content, "lantern", torch.position - Vector3(0, 1.4, 0), 1.0)
		# Decorative rocks stay inside the wall footprint, never the corridor.
		var wall_cell := layout.rooms[index].position - Vector2i.ONE
		Scenery.add(content, "rock", cell_to_world(wall_cell), 1.2)
		if index % 2 == 0:
			Scenery.add(content, "banner", cell_to_world(layout.rooms[index].position) + Vector3(-0.8, 1.1, 0), 1.0)
		else:
			Scenery.add(content, "boulder", cell_to_world(wall_cell), 1.1)
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.65, 0.3)
		light.light_energy = 1.4
		light.omni_range = 10.0
		light.position = torch.position + Vector3.UP
		content.add_child(light)
	add_child(content)

func _add_collision(body: StaticBody3D, size: Vector3, position_value: Vector3) -> void:
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	collision.position = position_value
	body.add_child(collision)

func _create_guard() -> CharacterBody3D:
	var body := Dummy.new()
	body.respawn_delay = 1e20
	body.collision_layer = 4
	body.collision_mask = 1
	var shape := CapsuleShape3D.new()
	shape.radius = 0.45
	shape.height = 1.8
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position.y = 0.9
	body.add_child(collision)
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.75, 0.7, 0.45)
	visual.mesh = mesh
	visual.material_override = Factory.get_shared_material(Color(0.5, 0.36, 0.23))
	visual.position.y = 0.9
	visual.name = "Body"
	body.add_child(visual)
	for side in [-1, 1]:
		var boot := Factory.create_box(Vector3(0.3, 0.55, 0.42), Color("39322e"))
		boot.position = Vector3(side * 0.22, -0.6, 0)
		visual.add_child(boot)
		var ear := Factory.create_box(Vector3(0.32, 0.18, 0.25), Color("7c9e36"))
		ear.position = Vector3(side * 0.49, 0.6, 0)
		ear.rotation.z = side * 0.3
		visual.add_child(ear)
	var head := Factory.create_box(Vector3(0.8, 0.6, 0.65), Color("7c9e36"))
	head.position.y = 0.65
	visual.add_child(head)
	for side in [-1, 1]:
		var eye := Factory.create_box(Vector3(0.13, 0.08, 0.03), Color("ffd35e"), 0.5)
		eye.position = Vector3(side * 0.2, 0.7, -0.34)
		visual.add_child(eye)
	var hurtbox := Area3D.new()
	hurtbox.name = "Hurtbox"
	hurtbox.collision_layer = 64
	hurtbox.collision_mask = 0
	hurtbox.monitoring = false
	var hurt_shape := CollisionShape3D.new()
	hurt_shape.shape = shape
	hurt_shape.position.y = 0.9
	hurtbox.add_child(hurt_shape)
	body.add_child(hurtbox)
	return body

func _on_guard_hit(_damage: int, hp: int) -> void:
	if hp == 0:
		guard_defeated = true

func try_collect_key(body: Node3D) -> bool:
	if not Orb.is_collector(body) or not guard_defeated or key_collected or cleared:
		return false
	key_collected = true
	var bus := Services.event_bus()
	if bus:
		bus.dungeon_gate_unlocked.emit()
	return true

func try_exit(body: Node3D) -> bool:
	if not Orb.is_collector(body) or not key_collected or cleared:
		return false
	cleared = true
	var bus := Services.event_bus()
	if bus:
		bus.floor_cleared.emit()
	exit_reached.emit()
	return true
