extends Area3D
## Original cyan restoration orb; legacy Atla names remain for signal compatibility.

const Services := preload("res://scripts/utilities/services.gd")
const Factory := preload("res://scripts/utilities/primitive_mesh_factory.gd")

@export var orb_id: String = ""
@export var piece_id: String = ""
var collected := false

func _ready() -> void:
	add_to_group(&"companion_pickups")
	collision_layer = 128
	collision_mask = 2
	monitorable = false
	var shape := SphereShape3D.new()
	shape.radius = 0.8
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position.y = 0.8
	add_child(collision)
	var mesh := Factory.create_atla_sphere_mesh()
	mesh.name = "OrbVisual"
	mesh.position.y = 0.9
	add_child(mesh)
	var seal := preload("res://scripts/utilities/art_mesh.gd").new()
	for index in 12:
		var a := index*TAU/12
		var b := (index+1)*TAU/12
		seal.pipe(Vector3(cos(a)*0.36,0,sin(a)*0.36),Vector3(cos(b)*0.36,0,sin(b)*0.36),0.025,Color("cfb97c"))
	seal.finish(mesh,"OrbSeal")
	body_entered.connect(try_collect)
	var state := Services.game_state()
	if state and state.has_collected_orb(orb_id):
		_retire()

static func is_collector(body: Node3D) -> bool:
	return is_instance_valid(body) and body.is_in_group(&"players") and body.has_method("is_alive") and body.get("is_player") == true and body.call("is_alive")

func _process(delta: float) -> void:
	$OrbVisual.rotation.y += delta
	$OrbVisual.position.y = 0.9 + sin(Time.get_ticks_msec() * 0.002) * 0.1

func try_collect(body: Node3D) -> bool:
	if collected or not is_collector(body):
		return false
	var state := Services.game_state()
	if state == null or not state.collect_restoration_orb(orb_id, piece_id):
		return false
	_retire()
	return true

func try_companion_collect(body: Node3D) -> bool:
	# Town parts are collectible even when the player is at full health.
	return try_collect(body)

func _retire() -> void:
	collected = true
	visible = false
	set_deferred("monitoring", false)
	queue_free()
