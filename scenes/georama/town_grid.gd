extends RefCounted
## A finite recovered-parts puzzle; coordinates are internal, not a building shop.

signal changed
const Piece := preload("res://data/georama/georama_piece_data.gd")
const Services := preload("res://scripts/utilities/services.gd")
const CELL_SIZE := 2.0
const SIZE := 64
const PARTS := ["mayor_house", "mayor_roof", "mayor_resident", "mayor_door", "mayor_bed", "mayor_stove", "cottage", "cottage_roof", "cottage_resident", "cottage_door", "cottage_bed", "tree", "bridge", "watermill", "mill_roof", "mill_wheel", "mill_resident", "path", "river"]
var catalog: Dictionary = {}
var state: Node

func _init() -> void:
	var mayor := preload("res://data/georama/mayor_house.tres")
	catalog[mayor.piece_id] = mayor
	for id in ["cottage", "tree", "bridge", "watermill", "path", "river"]:
		var piece := Piece.new()
		piece.piece_id = id
		piece.display_name = id.capitalize()
		piece.dimensions = Vector2i(3, 3) if id in ["cottage", "watermill"] else Vector2i.ONE
		if id == "bridge":
			piece.dimensions = Vector2i(3, 1)
		if id == "cottage":
			piece.slots = {"Roof": "cottage_roof", "Door": "cottage_door", "Bed": "cottage_bed", "Resident": "cottage_resident"}
			piece.resident_name = "Mira"
			piece.preferences = [{"kind": "neighbor", "piece_id": "tree", "distance": 4, "text": "I would love a tree near my house."}]
		if id == "watermill":
			piece.slots = {"Roof": "mill_roof", "Wheel": "mill_wheel", "Resident": "mill_resident"}
			piece.resident_name = "Bram"
			piece.service = "supplies"
			piece.preferences = [{"kind": "water", "distance": 1, "text": "My mill needs to stand beside the water."}]
		catalog[id] = piece

func bind_session(session: Node) -> void:
	state = session
	sync_parts()

func sync_parts() -> void:
	for id: String in state.collected_orb_ids:
		var type: String = state.collected_orb_ids[id]
		if catalog.has(type) and not state.town_objects.has(id):
			state.town_objects[id] = {"piece_id": type, "components": {}, "placed": false, "cell": Vector2i.ZERO, "rotation": 0, "requests_known": false, "event_seen": false}

func objects() -> Dictionary:
	return state.town_objects.duplicate(true)

func available_components() -> Array[String]:
	var used: Dictionary = {}
	for record: Dictionary in state.town_objects.values():
		for id: String in record.components.values():
			used[id] = true
	var result: Array[String] = []
	for id: String in state.collected_orb_ids:
		if not catalog.has(state.collected_orb_ids[id]) and not used.has(id):
			result.append(id)
	return result

func assemble(object_id: String, slot: String, part_id: String) -> bool:
	if not state.town_objects.has(object_id) or not available_components().has(part_id):
		return false
	var record: Dictionary = state.town_objects[object_id]
	var piece: Resource = catalog[record.piece_id]
	if is_complete(object_id) or record.components.has(slot) or piece.slots.get(slot, "") != state.collected_orb_ids[part_id]:
		return false
	record.components[slot] = part_id
	_notify()
	return true

func detach_component(object_id: String, slot: String) -> bool:
	if not state.town_objects.has(object_id) or is_complete(object_id):
		return false
	var record: Dictionary = state.town_objects[object_id]
	if not record.components.has(slot):
		return false
	record.components.erase(slot)
	_notify()
	return true

func is_complete(id: String) -> bool:
	if not state.town_objects.has(id):
		return false
	var record: Dictionary = state.town_objects[id]
	return record.components.size() == catalog[record.piece_id].slots.size()

func cells(piece_id: String, cell: Vector2i, rotation: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if not catalog.has(piece_id):
		return result
	var dimensions: Vector2i = catalog[piece_id].dimensions
	if rotation % 2 != 0:
		dimensions = Vector2i(dimensions.y, dimensions.x)
	for y in dimensions.y:
		for x in dimensions.x:
			result.append(cell + Vector2i(x, y))
	return result

func is_water(cell: Vector2i, ignore_id: String = "") -> bool:
	if cell.x >= 24 and cell.x <= 26:
		return true
	for id: String in state.town_objects:
		var record: Dictionary = state.town_objects[id]
		if id != ignore_id and record.placed and record.piece_id == "river" and cells("river", record.cell, record.rotation).has(cell):
			return true
	return false

func placement_error(id: String, cell: Vector2i, rotation: int) -> String:
	if not state.town_objects.has(id):
		return "Recover this foundation first."
	if rotation < 0 or rotation > 3:
		return "Rotation must be a quarter turn."
	var record: Dictionary = state.town_objects[id]
	var footprint := cells(record.piece_id, cell, rotation)
	for tile in footprint:
		if tile.x < 0 or tile.y < 0 or tile.x >= SIZE or tile.y >= SIZE:
			return "Outside the region."
		if record.piece_id not in ["bridge", "river"] and is_water(tile, id):
			return "This part needs dry land."
		for other_id: String in state.town_objects:
			var other: Dictionary = state.town_objects[other_id]
			if other_id != id and other.placed and not (record.piece_id == "bridge" and other.piece_id == "river") and not (record.piece_id == "river" and other.piece_id == "bridge") and cells(other.piece_id, other.cell, other.rotation).has(tile):
				return "Another recovered part occupies this space."
	return ""

func place(id: String, cell: Vector2i, rotation: int) -> bool:
	if not placement_error(id, cell, rotation).is_empty():
		return false
	var record: Dictionary = state.town_objects[id]
	record.cell = cell
	record.rotation = rotation
	record.placed = true
	_notify()
	var bus := Services.event_bus()
	if bus:
		bus.georama_piece_placed.emit(record.piece_id, Vector3i(cell.x, 0, cell.y))
	return true

func remove(id: String) -> bool:
	if not state.town_objects.has(id) or not state.town_objects[id].placed:
		return false
	var record: Dictionary = state.town_objects[id]
	record.placed = false
	_notify()
	var bus := Services.event_bus()
	if bus:
		bus.georama_piece_removed.emit(record.piece_id, Vector3i(record.cell.x, 0, record.cell.y))
	return true

func resident_active(id: String) -> bool:
	return state.town_objects.has(id) and state.town_objects[id].placed and is_complete(id) and not catalog[state.town_objects[id].piece_id].resident_name.is_empty()

func talk(id: String) -> String:
	if not resident_active(id):
		return "No resident has returned here yet."
	var record: Dictionary = state.town_objects[id]
	var piece: Resource = catalog[record.piece_id]
	var first: bool = not record.event_seen
	record.event_seen = true
	record.requests_known = true
	if not piece.service.is_empty():
		state.town_services[piece.service] = true
	_notify()
	var text := "%s: %s" % [piece.resident_name, "Thank you for bringing my home back!" if first else "Welcome back."]
	for rule: Dictionary in piece.preferences:
		text += "\n" + rule.text
	if not piece.service.is_empty():
		text += "\nService restored: " + piece.service.capitalize()
	return text

func _distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)

func request_results(id: String) -> Array[bool]:
	var results: Array[bool] = []
	if not state.town_objects.has(id):
		return results
	var record: Dictionary = state.town_objects[id]
	var footprint := cells(record.piece_id, record.cell, record.rotation)
	for rule: Dictionary in catalog[record.piece_id].preferences:
		var satisfied := false
		if record.placed and is_complete(id):
			if rule.kind == "facing":
				satisfied = record.rotation == int(rule.rotation)
			elif rule.kind == "water":
				for tile in footprint:
					for y in range(maxi(0, tile.y - int(rule.distance)), mini(SIZE, tile.y + int(rule.distance) + 1)):
						for x in range(maxi(0, tile.x - int(rule.distance)), mini(SIZE, tile.x + int(rule.distance) + 1)):
							if _distance(tile, Vector2i(x, y)) <= int(rule.distance) and is_water(Vector2i(x, y)):
								satisfied = true
			elif rule.kind in ["neighbor", "away", "landmark"]:
				satisfied = rule.kind == "away"
				for other_id: String in state.town_objects:
					var other: Dictionary = state.town_objects[other_id]
					if other_id != id and other.placed and other.piece_id == rule.piece_id:
						var distance := 1000000
						for a in footprint:
							for b in cells(other.piece_id, other.cell, other.rotation):
								distance = mini(distance, _distance(a, b))
						if rule.kind == "neighbor":
							satisfied = satisfied or distance <= int(rule.distance)
						elif rule.kind == "away":
							satisfied = satisfied and distance >= int(rule.distance)
						else:
							var offset: Vector2i = other.cell - record.cell
							var facing: int = (1 if offset.x > 0 else 3) if absi(offset.x) > absi(offset.y) else (2 if offset.y > 0 else 0)
							satisfied = satisfied or (offset != Vector2i.ZERO and record.rotation == facing)
		results.append(satisfied)
	return results

func analysis() -> Dictionary:
	var recovered: Dictionary = {}
	for type: String in state.collected_orb_ids.values():
		if PARTS.has(type):
			recovered[type] = true
	var placed: Dictionary = {}
	var fulfilled := 0
	var request_total := 0
	for piece: Resource in catalog.values():
		request_total += piece.preferences.size()
	for id: String in state.town_objects:
		var record: Dictionary = state.town_objects[id]
		if record.placed:
			placed[record.piece_id] = true
			for part: String in record.components.values():
				placed[state.collected_orb_ids[part]] = true
		if record.requests_known:
			for result in request_results(id):
				fulfilled += 1 if result else 0
	return {"collection": 100.0 * recovered.size() / PARTS.size(), "complete": 100.0 * placed.size() / PARTS.size(), "request": 100.0 * fulfilled / maxi(1, request_total)}

func _notify() -> void:
	state.town_services.clear()
	for id: String in state.town_objects:
		var record: Dictionary = state.town_objects[id]
		var service: String = catalog[record.piece_id].service
		if record.event_seen and resident_active(id) and not service.is_empty():
			state.town_services[service] = true
	changed.emit()
	var bus := Services.event_bus()
	if bus:
		for id: String in state.town_objects:
			var results := request_results(id)
			var score := 100.0 if results.is_empty() else 100.0 * results.count(true) / results.size()
			bus.georama_satisfaction_updated.emit(state.town_objects[id].piece_id, score)
		var progress := analysis()
		if not state.town_completed and progress.collection == 100 and progress.complete == 100 and progress.request == 100:
			state.town_completed = true
			bus.town_restoration_completed.emit()
