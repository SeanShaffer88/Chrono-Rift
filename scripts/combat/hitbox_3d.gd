extends Area3D
## One acknowledged hit per receiver per active window; rejected hits may retry.

var active := false
var _hit_targets: Dictionary = {}

func set_active(value: bool) -> void:
	if value == active:
		return
	active = value
	if active:
		_hit_targets.clear()
	set_deferred("monitoring", value)

func try_hit(area: Area3D, source: Node, damage: int, elements: Dictionary = {}, slayers: Dictionary = {}) -> Node:
	if not active or damage <= 0 or not is_instance_valid(area):
		return null
	var target: Node = area
	if not target.has_method("receive_weapon_hit") and not target.has_method("receive_hit") and not target.has_method("take_damage"):
		target = area.get_parent()
	if target == null or target == source or target.get_parent() == source:
		return null
	var receiver := target
	if target == area and (area.get_parent().has_method("take_damage") or area.get_parent().has_method("receive_hit")):
		receiver = area.get_parent()
	var id := receiver.get_instance_id()
	if _hit_targets.has(id):
		return null
	# Reserve before calling receivers: damage signals can reenter this method.
	_hit_targets[id] = true
	var accepted := false
	if target.has_method("receive_weapon_hit"):
		accepted = target.call("receive_weapon_hit", damage, source, elements.duplicate(true), slayers.duplicate(true)) == true
	elif target.has_method("receive_hit"):
		accepted = target.call("receive_hit", damage, source) == true
	elif target.has_method("take_damage"):
		accepted = target.call("take_damage", damage) == true
	if not accepted:
		_hit_targets.erase(id)
		return null
	return receiver
