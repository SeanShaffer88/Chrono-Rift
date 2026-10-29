extends Area3D
## Receiver adapter. Dodge invulnerability remains owned by the character.

signal hit_received(damage: int, source: Node, elements: Dictionary, slayers: Dictionary)
@export var iframe_duration: float = 0.0
var _iframe_left := 0.0

func _physics_process(delta: float) -> void:
	_iframe_left = maxf(0.0, _iframe_left - delta)

func receive_weapon_hit(damage: int, source: Node, elements: Dictionary, slayers: Dictionary) -> bool:
	if damage <= 0 or _iframe_left > 0.0 or get_parent() == source:
		return false
	var receiver := get_parent()
	var accepted := false
	if receiver.has_method("receive_hit"):
		accepted = receiver.call("receive_hit", damage, source) == true
	elif receiver.has_method("take_damage"):
		accepted = receiver.call("take_damage", damage) == true
	if accepted:
		_iframe_left = maxf(0.0, iframe_duration)
		hit_received.emit(damage, source, elements, slayers)
	return accepted
