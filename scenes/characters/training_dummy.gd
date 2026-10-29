extends CharacterBody3D
## Stationary target for testing lock-on and weapon hits. Flashes when hit and
## refills its HP after a short delay once knocked down.

signal hit_received(damage: int, current_hp: int)

@export var max_hp: int = 60
@export var respawn_delay: float = 2.0
@export var flash_color: Color = Color(1.0, 0.35, 0.3)

var current_hp: int
var _flash_time := 0.0
var _respawn_time := 0.0

@onready var _body_mesh: MeshInstance3D = $Body

var _material: StandardMaterial3D
var _base_color: Color
var _body_layer: int
var _hurtbox_layer: int

func _ready() -> void:
	add_to_group(&"enemies")
	current_hp = max_hp
	_body_layer = collision_layer
	_hurtbox_layer = $Hurtbox.collision_layer
	# Each dummy flashes independently, so it owns its material.
	_material = (_body_mesh.material_override as StandardMaterial3D).duplicate()
	_body_mesh.material_override = _material
	_base_color = _material.albedo_color

func _physics_process(delta: float) -> void:
	if _flash_time > 0.0:
		_flash_time = maxf(0.0, _flash_time - delta)
		_material.albedo_color = flash_color if _flash_time > 0.0 else _base_color
	if not is_alive():
		_respawn_time -= delta
		if _respawn_time <= 0.0:
			current_hp = max_hp
			visible = true
			_set_collidable(true)

func receive_hit(damage: int, _source: Node) -> bool:
	if damage <= 0 or not is_alive():
		return false
	current_hp = maxi(0, current_hp - damage)
	_flash_time = 0.12
	hit_received.emit(damage, current_hp)
	if current_hp == 0:
		visible = false
		_set_collidable(false)
		_respawn_time = respawn_delay
	return true

func _set_collidable(enabled: bool) -> void:
	set_deferred("collision_layer", _body_layer if enabled else 0)
	$Hurtbox.set_deferred("collision_layer", _hurtbox_layer if enabled else 0)

func is_alive() -> bool:
	return current_hp > 0
