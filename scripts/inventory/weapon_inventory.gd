extends Node
## Owns weapon instances. Mutations finish before outward notifications.

signal inventory_changed
signal equipped_changed(weapon: Resource)

const Weapon := preload("res://data/weapons/weapon_data.gd")
const Services := preload("res://scripts/utilities/services.gd")
const STARTER := preload("res://data/weapons/battle_wrench.tres")

var _weapons: Array[Weapon] = []
var _equipped: Weapon = null
var equipped_weapon: Weapon:
	get: return _equipped

func get_weapons() -> Array[Weapon]:
	return _weapons.duplicate()

func add_weapon(template: Weapon) -> Weapon:
	if template == null or template.is_broken or template.max_durability <= 0.0:
		return null
	var instance := template.duplicate(true) as Weapon
	_weapons.append(instance)
	_connect_weapon(instance)
	inventory_changed.emit()
	return instance

func _connect_weapon(weapon: Weapon) -> void:
	weapon.broken.connect(_on_broken)
	weapon.durability_changed.connect(_on_durability_changed.bind(weapon))

func _disconnect_weapon(weapon: Weapon) -> void:
	weapon.broken.disconnect(_on_broken)
	weapon.durability_changed.disconnect(_on_durability_changed.bind(weapon))

func equip(weapon: Weapon) -> bool:
	if weapon != null and (not _weapons.has(weapon) or (weapon.is_broken and weapon.destroy_on_break)):
		return false
	if weapon == _equipped:
		return true
	_equipped = weapon
	_emit_equipped()
	return true

func remove_weapon(weapon: Weapon) -> bool:
	if not _weapons.has(weapon):
		return false
	_weapons.erase(weapon)
	_disconnect_weapon(weapon)
	if _equipped == weapon:
		_equipped = null
		_emit_equipped()
	inventory_changed.emit()
	return true

func repair_weapon(weapon: Weapon, amount: float) -> bool:
	return _weapons.has(weapon) and weapon.repair(amount)

func apply_hit_wear(weapon: Weapon) -> bool:
	return weapon != null and _weapons.has(weapon) and weapon.apply_degradation(weapon.degradation_rate)

func build_up(weapon: Weapon, branch_index: int) -> Weapon:
	if not _weapons.has(weapon) or not weapon.can_build_up(branch_index):
		return null
	var path := str(weapon.build_up_branches[branch_index].get("target_path", ""))
	if not path.begins_with("res://data/weapons/") or not ResourceLoader.exists(path):
		return null
	var template := load(path) as Weapon
	if template == null or template.is_broken or template.max_durability <= 0.0:
		return null
	var evolved := template.duplicate(true) as Weapon
	evolved.base_attack = maxi(evolved.base_attack, weapon.base_attack)
	for key in weapon.elemental_stats:
		evolved.elemental_stats[key] = maxi(int(evolved.elemental_stats.get(key, 0)), int(weapon.elemental_stats[key]))
	for key in weapon.slayer_stats:
		evolved.slayer_stats[key] = maxi(int(evolved.slayer_stats.get(key, 0)), int(weapon.slayer_stats[key]))
	evolved.current_durability = evolved.max_durability
	evolved.is_broken = false
	var index := _weapons.find(weapon)
	_disconnect_weapon(weapon)
	_weapons[index] = evolved
	_connect_weapon(evolved)
	if _equipped == weapon:
		_equipped = evolved
		_emit_equipped()
	inventory_changed.emit()
	var bus := Services.event_bus()
	if bus:
		bus.weapon_built_up.emit(weapon, evolved)
	return evolved

func reset(with_starter: bool = true) -> void:
	for weapon in _weapons:
		_disconnect_weapon(weapon)
	_weapons.clear()
	_equipped = null
	if with_starter:
		var starter := STARTER.duplicate(true) as Weapon
		_weapons.append(starter)
		_connect_weapon(starter)
		_equipped = starter
	_emit_equipped()
	inventory_changed.emit()

func _on_broken(weapon: Resource) -> void:
	if weapon.destroy_on_break:
		remove_weapon(weapon)

func _on_durability_changed(weapon: Weapon) -> void:
	if weapon == _equipped:
		_emit_durability()

func _emit_equipped() -> void:
	equipped_changed.emit(_equipped)
	var bus := Services.event_bus()
	if bus:
		bus.weapon_equipped.emit(_equipped)
	_emit_durability()

func _emit_durability() -> void:
	var bus := Services.event_bus()
	if bus:
		bus.weapon_durability_changed.emit(_equipped.current_durability if _equipped else 0.0, _equipped.max_durability if _equipped else 0.0, _equipped.is_broken if _equipped else false)

func _exit_tree() -> void:
	for weapon in _weapons:
		_disconnect_weapon(weapon)
