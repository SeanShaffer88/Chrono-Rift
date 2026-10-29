extends Node
## Session-wide game state: active character, thirst gauge, Atla inventory and mode.

enum Mode { DUNGEON, GEORAMA }

signal mode_changed(new_mode: Mode)
signal thirst_depleted

const MAX_THIRST := 100.0

const Services := preload("res://scripts/utilities/services.gd")

@export var thirst_drain_per_second: float = 0.5

var mode: Mode = Mode.DUNGEON
var active_character_id: String = "melee_hero"
var thirst: float = MAX_THIRST
var atla_inventory: Array[String] = []

func _process(delta: float) -> void:
	if mode == Mode.DUNGEON:
		drain_thirst(thirst_drain_per_second * delta)

func set_mode(new_mode: Mode) -> void:
	if new_mode == mode:
		return
	mode = new_mode
	mode_changed.emit(mode)

func swap_character(character_id: String) -> void:
	if character_id == active_character_id:
		return
	active_character_id = character_id
	var bus := Services.event_bus()
	if bus:
		bus.character_swapped.emit(character_id)

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
	active_character_id = "melee_hero"
	thirst = MAX_THIRST
	atla_inventory.clear()
	_emit_thirst()

func _emit_thirst() -> void:
	var bus := Services.event_bus()
	if bus:
		bus.thirst_changed.emit(thirst, MAX_THIRST)
