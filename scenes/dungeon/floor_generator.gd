extends Node3D

signal exit_reached
const EnvironmentArt = preload("res://scenes/environment/environment_art.gd")
const BSP := preload("res://scripts/utilities/bsp_tree.gd")
const Factory := preload("res://scripts/utilities/primitive_mesh_factory.gd")
const Orb := preload("res://scenes/dungeon/atla_sphere.gd")
const Pickup := preload("res://scenes/dungeon/dungeon_pickup.gd")
const Healing = preload("res://scenes/dungeon/healing_pickup.gd")
const Encounters=preload("res://scripts/combat/encounter_layout.gd")
const Profiles=preload("res://scripts/combat/enemy_profiles.gd")
var encounter_plan: Dictionary = {}
var encounters: Dictionary = {}
const Guard := preload("res://scenes/characters/dungeon_guard.gd")
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
var wall_fade: Node
var guard: Node3D = null
var collected_healing: Array[String] = []

func generate(seed_value: int, number: int = 1, build_geometry: bool = true) -> bool:
	var candidate := BSP.new()
	if number < 1 or orb_count < 1 or orb_count > 20 or not candidate.generate(seed_value, grid_size,preload("res://scripts/utilities/dungeon_biomes.gd").for_floor(number)):
		return false
	# Validate before replacing a playable floor.
	layout = candidate
	floor_seed = seed_value
	floor_number = number
	key_collected = false
	guard_defeated = false
	cleared = false
	collected_healing.clear()
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
	var encounter_reserved: Array=reserved.duplicate()
	encounter_reserved.append_array(orb_cells)
	for room: Rect2i in layout.rooms.slice(0,3): encounter_reserved.append(room.get_center()+Vector2i.DOWN)
	encounter_plan=Encounters.plan(layout.rooms,layout.walkable,encounter_reserved,seed_value)
	encounters.clear()
	if is_instance_valid(content):
		content.free()
	content = null
	wall_fade=null
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
	var biome := preload("res://scripts/utilities/dungeon_biomes.gd").for_floor(floor_number)
	EnvironmentArt.dungeon(content, layout.walkable, floor_seed,biome)
	preload("res://scenes/environment/dungeon_landmarks.gd").build(content,layout.rooms,layout.walkable,floor_seed,biome)
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
	for role: String in encounter_plan:
		var enemy := create_enemy(role,encounter_plan[role])
		enemy.name=role.capitalize()
		enemy.position=cell_to_world(encounter_plan[role])
		encounters[role]=enemy
		content.add_child(enemy)
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
		healing.floor_owner = self
		healing.pickup_id = "%d:%d" % [cell.x, cell.y]
		healing.position = cell_to_world(cell)
		content.add_child(healing)
	var light_count := 0
	for index in layout.rooms.size():
		var room: Rect2i = layout.rooms[index]
		var light_needed := index < 6 or room.has_point(key_cell) or room.has_point(exit_cell)
		var at := cell_to_world(room.position + Vector2i(room.size.x / 2, 0)) - Vector3(0, 0, 0.9)
		EnvironmentArt.torch(content, at, 0.0, light_needed and light_count < 8)
		if light_needed:
			light_count += 1

	var fade_roots: Array[Node]=[]
	for name_value: String in ["WallBatch","WallDetailBatch","PierBatch","MasonryCourses","SolidRockBacking","FacetedSlateCap"]:
		var geometry_root := content.find_child(name_value,true,false)
		if geometry_root!=null: fade_roots.append(geometry_root)
	wall_fade=preload("res://scripts/utilities/wall_fade_bindings.gd").create(content,fade_roots)
	add_child(content)

func _add_collision(body: StaticBody3D, size: Vector3, position_value: Vector3) -> void:
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	collision.position = position_value
	body.add_child(collision)

func _create_guard() -> CharacterBody3D:
	return create_enemy("guard",guard_cell)

func create_enemy(role: String,cell: Vector2i) -> CharacterBody3D:
	var body := Guard.new()
	body.role=role if role in Profiles.ROLES else "guard"
	body.floor_owner = self
	body.art_biome = preload("res://scripts/utilities/dungeon_biomes.gd").for_floor(floor_number)
	for offset in [Vector2i.ZERO, Vector2i(0, 2), Vector2i(2, 0)]:
		if layout.walkable.has(cell + offset):
			body.patrol_points.append(cell_to_world(cell + offset))
	body.respawn_delay = 1e20
	body.collision_layer = 4
	body.collision_mask = 7
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
	var hurtbox := Area3D.new()
	hurtbox.name = "Hurtbox"
	hurtbox.collision_layer = 64
	hurtbox.collision_mask = 0
	hurtbox.set_script(preload("res://scripts/combat/hurtbox_3d.gd"))
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

func progress_snapshot() -> Dictionary:
	var records: Array=[]
	for role: String in Profiles.ROLES:
		var enemy: Node3D=encounters.get(role)
		records.append({"id":role,"hp":enemy.current_hp if is_instance_valid(enemy) and enemy.is_alive() else 0})
	return {"encounters":records,"key": key_collected, "guard_defeated": guard_defeated, "guard_hp": guard.current_hp if is_instance_valid(guard) else (0 if guard_defeated else 60), "healing": collected_healing.duplicate()}

func restore_progress(record: Dictionary) -> void:
	for entry: Dictionary in record.encounters:
		var enemy: Node3D=encounters.get(entry.id)
		if not is_instance_valid(enemy): continue
		enemy.cancel_projectiles()
		if int(entry.hp)==0: enemy.receive_hit(enemy.max_hp,self)
		else:
			enemy.current_hp=int(entry.hp)
			enemy._set_state(enemy.State.PATROL)
	key_collected = record.key
	guard_defeated = record.guard_defeated
	collected_healing.assign(record.healing)
	if is_instance_valid(guard):
		if guard_defeated:
			guard.receive_hit(guard.max_hp, self)
		else:
			guard.current_hp = int(record.guard_hp)
	if content != null:
		content.get_node("ExitGate")._update_gate()
		if key_collected:
			content.get_node("GateKey").free()
		for child: Node in content.get_children():
			if child is Healing and collected_healing.has(child.pickup_id):
				child.free()

func find_guard_path(from: Vector3, destination: Vector3) -> Array[Vector3]:
	var start := Vector2i(roundi(from.x / CELL_SIZE), roundi(from.z / CELL_SIZE))
	var goal := Vector2i(roundi(destination.x / CELL_SIZE), roundi(destination.z / CELL_SIZE))
	var route: Array[Vector3] = []
	if not layout.walkable.has(start) or not layout.walkable.has(goal):
		return route
	var distances := layout.distances_from(goal)
	var cell := start
	while cell != goal:
		var next := cell
		for direction: Vector2i in BSP.DIRECTIONS:
			var neighbor := cell + direction
			if distances.get(neighbor, INF) < distances.get(next, INF):
				next = neighbor
		if next == cell:
			return []
		route.append(cell_to_world(next))
		cell = next
	if route.is_empty():
		route.append(destination)
	return route

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
