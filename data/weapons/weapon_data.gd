class_name WeaponData
extends Resource
## Templates are immutable by convention; inventory owns deep duplicates.

signal durability_changed
signal broken(weapon: Resource)

enum ElementType { NONE, FIRE, ICE, THUNDER, WIND, HOLY }
enum SlayerType { NONE, BEAST, UNDEAD, MAGE, SKY, MIMIC, METAL, AQUATIC }

const Services := preload("res://scripts/utilities/services.gd")

@export var weapon_id: String = ""
@export var display_name: String = "Sturdy Blade"
@export var base_attack: int = 15
@export var current_durability: float = 60.0
@export var max_durability: float = 60.0
@export var is_broken: bool = false
@export var degradation_rate: float = 0.45
@export var destroy_on_break: bool = true
@export var elemental_stats: Dictionary = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0}
@export var slayer_stats: Dictionary = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0, 7: 0}
## Branch keys: target_path, req_atk, req_elem and req_slayer.
@export var build_up_branches: Array[Dictionary] = []

func get_effective_attack() -> int:
	return maxi(1, int(base_attack * 0.1)) if is_broken else maxi(1, base_attack)

func apply_degradation(amount: float) -> bool:
	if not is_finite(amount) or amount <= 0.0 or is_broken:
		return false
	current_durability = maxf(0.0, current_durability - amount)
	is_broken = current_durability == 0.0
	durability_changed.emit()
	emit_changed()
	if is_broken:
		broken.emit(self)
		var bus := Services.event_bus()
		if bus:
			bus.weapon_broken.emit(self)
	return true

func repair(amount: float) -> bool:
	if not is_finite(amount) or amount <= 0.0 or max_durability <= 0.0:
		return false
	var restored := minf(max_durability, current_durability + amount)
	if restored <= current_durability:
		return false
	current_durability = restored
	is_broken = false
	durability_changed.emit()
	emit_changed()
	return true

func can_build_up(branch_index: int) -> bool:
	if is_broken or branch_index < 0 or branch_index >= build_up_branches.size():
		return false
	var branch: Dictionary = build_up_branches[branch_index]
	if base_attack < int(branch.get("req_atk", 0)):
		return false
	for key in branch.get("req_elem", {}):
		if int(elemental_stats.get(key, 0)) < int(branch["req_elem"][key]):
			return false
	for key in branch.get("req_slayer", {}):
		if int(slayer_stats.get(key, 0)) < int(branch["req_slayer"][key]):
			return false
	return true
