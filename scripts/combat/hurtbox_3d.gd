extends Area3D
## Receiver adapter. Dodge invulnerability remains owned by the character.

signal hit_received(damage: int, source: Node, elements: Dictionary, slayers: Dictionary)
@export var iframe_duration: float = 0.0
var _iframe_left := 0.0

func _physics_process(delta: float) -> void:
	_iframe_left = maxf(0.0, _iframe_left - delta)

func receive_weapon_hit(damage: int, source: Node, elements: Dictionary, slayers: Dictionary) -> bool:
	return receive_combat_hit(damage,source,elements,slayers,false).accepted

func receive_combat_hit(damage: int,source: Node,elements: Dictionary,slayers: Dictionary,swallow: bool=false) -> Dictionary:
	var result := {"accepted":false,"damage":0,"swallowed":false}
	if damage<=0 or _iframe_left>0 or get_parent()==source: return result
	var receiver := get_parent()
	if receiver.has_method("receive_combat_hit"):
		result=receiver.receive_combat_hit(damage,source,elements,slayers,swallow)
	else:
		var consumed := false
		if swallow and receiver.has_method("get_swallow_damage"):
			damage=int(receiver.get_swallow_damage(damage))
			consumed=not bool(receiver.get("is_boss"))
		var accepted := false
		if receiver.has_method("receive_hit"): accepted=receiver.receive_hit(damage,source)==true
		elif receiver.has_method("take_damage"): accepted=receiver.take_damage(damage)==true
		result={"accepted":accepted,"damage":damage if accepted else 0,"swallowed":consumed and accepted}
	if result.get("accepted",false):
		_iframe_left=maxf(0,iframe_duration)
		hit_received.emit(int(result.damage),source,elements,slayers)
	return result
