extends Node
## Session-wide game state: active character, thirst gauge, Atla inventory and mode.

enum Mode { DUNGEON, GEORAMA }

signal mode_changed(new_mode: Mode)
signal thirst_depleted

const MAX_THIRST := 100.0

const Services := preload("res://scripts/utilities/services.gd")
const WeaponInventory := preload("res://scripts/inventory/weapon_inventory.gd")
const Roster = preload("res://data/characters/character_roster.gd")

var weapon_inventory := WeaponInventory.new()
var character_inventories: Dictionary = {}

func _ready() -> void:
	add_child(weapon_inventory)
	weapon_inventory.reset()
	character_inventories["melee_hero"] = weapon_inventory
	for id: String in Roster.HEROES:
		if id == "melee_hero":
			continue
		var inventory := WeaponInventory.new()
		inventory.is_session_active = false
		add_child(inventory)
		inventory.reset(true, Roster.HEROES[id].starter)
		character_inventories[id] = inventory

@export var thirst_drain_per_second: float = 0.5

var mode: Mode = Mode.DUNGEON
var active_character_id: String = "melee_hero"
var thirst: float = MAX_THIRST
var atla_inventory: Array[String] = []
var collected_orb_ids: Dictionary = {}
var town_objects: Dictionary = {}
var town_services: Dictionary = {}
var town_completed := false

func has_collected_orb(orb_id: String) -> bool:
	return collected_orb_ids.has(orb_id)

func collect_restoration_orb(orb_id: String, piece_id: String) -> bool:
	if orb_id.is_empty() or piece_id.is_empty() or collected_orb_ids.has(orb_id):
		return false
	collected_orb_ids[orb_id] = piece_id
	atla_inventory.append(piece_id)
	var bus := Services.event_bus()
	if bus:
		bus.atla_collected.emit(orb_id, piece_id)
	return true

func _process(delta: float) -> void:
	if mode == Mode.DUNGEON:
		drain_thirst(thirst_drain_per_second * delta)

func set_mode(new_mode: Mode) -> void:
	if new_mode == mode:
		return
	mode = new_mode
	mode_changed.emit(mode)

func swap_character(character_id: String) -> bool:
	if not Roster.HEROES.has(character_id) or not character_inventories.has(character_id):
		return false
	if character_id == active_character_id:
		return true
	weapon_inventory.is_session_active = false
	weapon_inventory = character_inventories[character_id]
	weapon_inventory.is_session_active = true
	active_character_id = character_id
	var bus := Services.event_bus()
	if bus:
		bus.character_swapped.emit(character_id)
	return true

func drain_thirst(amount: float) -> void:
	if amount <= 0.0 or thirst <= 0.0:
		return
	thirst = maxf(0.0, thirst - amount)
	_emit_thirst()
	if thirst == 0.0:
		thirst_depleted.emit()

func refill_thirst(amount: float = MAX_THIRST) -> void:
	thirst = minf(MAX_THIRST, thirst + amount)
	_emit_thirst()

func add_atla(piece_id: String) -> void:
	atla_inventory.append(piece_id)

func has_atla(piece_id: String) -> bool:
	return atla_inventory.has(piece_id)

func reset() -> void:
	mode = Mode.DUNGEON
	var previous_character := active_character_id
	active_character_id = "melee_hero"
	thirst = MAX_THIRST
	atla_inventory.clear()
	collected_orb_ids.clear()
	town_objects.clear()
	town_services.clear()
	town_completed = false
	if not character_inventories.is_empty():
		weapon_inventory = character_inventories["melee_hero"]
		for id: String in character_inventories:
			var inventory: Node = character_inventories[id]
			inventory.is_session_active = id == active_character_id
			inventory.reset(true, Roster.HEROES[id].starter)
	else:
		weapon_inventory.reset()
	if previous_character != active_character_id and Services.event_bus():
		Services.event_bus().character_swapped.emit(active_character_id)
	_emit_thirst()

func _emit_thirst() -> void:
	var bus := Services.event_bus()
	if bus:
		bus.thirst_changed.emit(thirst, MAX_THIRST)
