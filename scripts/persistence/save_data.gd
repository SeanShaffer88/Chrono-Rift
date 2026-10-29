extends RefCounted
## Explicit JSON contract; no object deserialization or resource paths from saves.
const Weapon = preload("res://data/weapons/weapon_data.gd")
const Grid = preload("res://scenes/georama/town_grid.gd")
const Roster = preload("res://data/characters/character_roster.gd")
const TEMPLATES = {
	"trail_sword": preload("res://data/weapons/trail_sword.tres"),
	"battle_wrench": preload("res://data/weapons/battle_wrench.tres"),
	"gladius": preload("res://data/weapons/gladius.tres"),
	"duskblade": preload("res://data/weapons/duskblade.tres"),
	"rift_chain": preload("res://data/weapons/rift_chain.tres"),
}

static func number(value: Variant, low: float, high: float, integer: bool = false) -> bool:
	return (value is float or value is int) and is_finite(float(value)) and value >= low and value <= high and (not integer or value == floor(value))

static func vector(value: Variant, limit: float = 10000.0) -> bool:
	return value is Array and value.size() == 3 and number(value[0], -limit, limit) and number(value[1], -limit, limit) and number(value[2], -limit, limit)

static func pack_vector(value: Vector3) -> Array:
	return [value.x, value.y, value.z]

static func unpack_vector(value: Array) -> Vector3:
	return Vector3(value[0], value[1], value[2])

static func actor(hero: Node3D) -> Dictionary:
	return {"position": pack_vector(hero.position), "hp": hero.current_hp, "facing": pack_vector(hero.facing_direction), "yaw": hero.camera_rig.get_preferred_yaw(), "pitch": hero.camera_rig.preferred_pitch}

static func valid_actor(value: Variant) -> bool:
	return value is Dictionary and vector(value.get("position")) and vector(value.get("facing"), 1.01) and number(value.get("hp"), 0, 100, true) and number(value.get("yaw"), -100000, 100000) and number(value.get("pitch"), deg_to_rad(-60.0)-0.000001, -0.2)

static func capture(state: Node, dungeon: Node) -> Dictionary:
	var inventories := {}
	for id: String in Roster.HEROES:
		var inventory: Node = state.character_inventories[id]
		var weapons: Array = inventory.get_weapons()
		var records: Array = []
		for weapon: Resource in weapons:
			var elements: Array = []
			var slayers: Array = []
			for key in range(1, 6): elements.append(weapon.elemental_stats.get(key, 0))
			for key in range(1, 8): slayers.append(weapon.slayer_stats.get(key, 0))
			records.append({"id": weapon.weapon_id, "attack": weapon.base_attack, "durability": weapon.current_durability, "maximum": weapon.max_durability, "rate": weapon.degradation_rate, "destroy": weapon.destroy_on_break, "elements": elements, "slayers": slayers})
		inventories[id] = {"weapons": records, "equipped": weapons.find(inventory.equipped_weapon)}
	var objects := {}
	for id: String in state.town_objects:
		var record: Dictionary = state.town_objects[id].duplicate(true)
		record.cell = [record.cell.x, record.cell.y]
		objects[id] = record
	var floor_state: Dictionary = dungeon.floor_generator.progress_snapshot()
	return {"active": state.active_character_id, "thirst": state.thirst, "atla": state.atla_inventory.duplicate(), "orbs": state.collected_orb_ids.duplicate(), "town": objects, "town_completed": state.town_completed, "inventories": inventories, "dungeon_seed": dungeon.dungeon_seed, "floor_number": dungeon.floor_number, "hero": actor(dungeon.get_node("MeleeHero")), "floor": floor_state, "town_visit": {"editing": dungeon.town_view.editing, "hero": actor(dungeon.town_view.get_node("MeleeHero"))} if is_instance_valid(dungeon.town_view) else {}}

static func validate(data: Dictionary) -> bool:
	if not Roster.HEROES.has(data.get("active")) or not number(data.get("thirst"), 0, 100) or not valid_actor(data.get("hero")):
		return false
	if not number(data.get("dungeon_seed"), -2147483648, 2147483647, true) or not number(data.get("floor_number"), 1, 100000, true):
		return false
	var floor_state: Variant = data.get("floor")
	if not floor_state is Dictionary or not floor_state.get("key") is bool or not floor_state.get("guard_defeated") is bool or not number(floor_state.get("guard_hp"), 0, 60, true):
		return false
	if floor_state.key and not floor_state.guard_defeated or floor_state.guard_defeated != (floor_state.guard_hp == 0):
		return false
	if not floor_state.get("healing") is Array or floor_state.healing.size() > 3:
		return false
	var used_healing := {}
	for value: Variant in floor_state.healing:
		if not value is String or value.length() > 24 or used_healing.has(value): return false
		used_healing[value] = true
	var visit: Variant = data.get("town_visit")
	if not visit is Dictionary or (not visit.is_empty() and (not visit.get("editing") is bool or not valid_actor(visit.get("hero")))):
		return false
	if not data.get("town_completed") is bool or not _inventories_valid(data.get("inventories")):
		return false
	return _town_valid(data)

static func _inventories_valid(inventories: Variant) -> bool:
	if not inventories is Dictionary or inventories.size() != Roster.HEROES.size(): return false
	for id: String in Roster.HEROES:
		var inventory: Variant = inventories.get(id)
		if not inventory is Dictionary or not inventory.get("weapons") is Array or inventory.weapons.size() > 100: return false
		if not number(inventory.get("equipped"), -1, inventory.weapons.size() - 1, true): return false
		for item: Variant in inventory.weapons:
			if not item is Dictionary or not TEMPLATES.has(item.get("id")) or not item.get("destroy") is bool: return false
			if not number(item.get("attack"), 0, 100000, true) or not number(item.get("maximum"), 0.001, 100000) or not number(item.get("durability"), 0, item.maximum) or not number(item.get("rate"), 0, 100000): return false
			if item.destroy and item.durability == 0: return false
			for stats in ["elements", "slayers"]:
				if not item.get(stats) is Array or item[stats].size() != (5 if stats == "elements" else 7): return false
				for value: Variant in item[stats]:
					if not number(value, 0, 100000, true): return false
	return true

static func _town_valid(data: Dictionary) -> bool:
	var orbs: Variant = data.get("orbs")
	var objects: Variant = data.get("town")
	var atla: Variant = data.get("atla")
	if not orbs is Dictionary or orbs.size() > 256 or not objects is Dictionary or objects.size() > orbs.size() or not atla is Array or atla.size() > 256: return false
	for id: Variant in orbs:
		if not id is String or id.is_empty() or id.length() > 200 or not Grid.PARTS.has(orbs[id]): return false
	for value: Variant in atla:
		if not Grid.PARTS.has(value): return false
	var grid := Grid.new()
	var used := {}
	var occupied := {}
	for id: Variant in objects:
		var record: Variant = objects[id]
		if not orbs.has(id) or not record is Dictionary or record.get("piece_id") != orbs[id] or not grid.catalog.has(record.piece_id): return false
		for flag in ["placed", "requests_known", "event_seen"]:
			if not record.get(flag) is bool: return false
		if not record.get("cell") is Array or record.cell.size() != 2 or not number(record.cell[0], 0, 63, true) or not number(record.cell[1], 0, 63, true) or not number(record.get("rotation"), 0, 3, true): return false
		if not record.get("components") is Dictionary: return false
		var slots: Dictionary = grid.catalog[record.piece_id].slots
		for slot: Variant in record.components:
			var part: Variant = record.components[slot]
			if not slots.has(slot) or not part is String or not orbs.has(part) or slots[slot] != orbs[part] or used.has(part): return false
			used[part] = true
		if record.placed:
			for cell: Vector2i in grid.cells(record.piece_id, Vector2i(record.cell[0], record.cell[1]), int(record.rotation)):
				if cell.x >= 64 or cell.y >= 64 or (cell.x >= 24 and cell.x <= 26 and record.piece_id not in ["bridge", "river"]): return false
				var existing: String = occupied.get(cell, "")
				if not existing.is_empty() and not (existing == "river" and record.piece_id == "bridge") and not (existing == "bridge" and record.piece_id == "river"): return false
				occupied[cell] = record.piece_id
	return true

static func apply_state(state: Node, data: Dictionary) -> void:
	# Only call after complete validation; resource instances are owned duplicates.
	for inventory: Node in state.character_inventories.values(): inventory.is_session_active = false
	for id: String in Roster.HEROES:
		var weapons: Array[Weapon] = []
		for record: Dictionary in data.inventories[id].weapons:
			var item: Weapon = TEMPLATES[record.id].duplicate(true)
			item.base_attack = int(record.attack)
			item.max_durability = float(record.maximum)
			item.current_durability = float(record.durability)
			item.degradation_rate = float(record.rate)
			item.destroy_on_break = record.destroy
			item.is_broken = item.current_durability == 0
			for index in 5: item.elemental_stats[index + 1] = int(record.elements[index])
			for index in 7: item.slayer_stats[index + 1] = int(record.slayers[index])
			weapons.append(item)
		state.character_inventories[id].restore_weapons(weapons, int(data.inventories[id].equipped))
	state.thirst = float(data.thirst)
	state.atla_inventory.assign(data.atla)
	state.collected_orb_ids = data.orbs.duplicate(true)
	state.town_objects = data.town.duplicate(true)
	for record: Dictionary in state.town_objects.values(): record.cell = Vector2i(record.cell[0], record.cell[1])
	state.town_completed = data.town_completed
	state.active_character_id = data.active
	state.weapon_inventory = state.character_inventories[data.active]
	state.weapon_inventory.is_session_active = true
	var grid := Grid.new()
	grid.bind_session(state)
	grid._notify()
	state._emit_thirst()
	preload("res://scripts/utilities/services.gd").event_bus().character_swapped.emit(data.active)
