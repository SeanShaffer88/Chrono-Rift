extends Area3D
## Key and exit triggers delegate authoritative progression to their floor.

const Orb := preload("res://scenes/dungeon/atla_sphere.gd")
const Factory := preload("res://scripts/utilities/primitive_mesh_factory.gd")
enum Kind { KEY, EXIT }
var kind: Kind = Kind.KEY
var floor_owner: Node = null
var gate_material: ShaderMaterial

func _ready() -> void:
	if kind == Kind.KEY:
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
	if kind == Kind.KEY:
		preload("res://scenes/environment/pickup_art.gd").key(self)
	else:
		gate_material = preload("res://scenes/environment/pickup_art.gd").gate(self)
		_update_gate()
		var bus := preload("res://scripts/utilities/services.gd").event_bus()
		if bus: bus.dungeon_gate_unlocked.connect(_update_gate)
	body_entered.connect(try_activate)

func _update_gate() -> void:
	if gate_material != null:
		var unlocked: bool = is_instance_valid(floor_owner) and floor_owner.key_collected
		gate_material.set_shader_parameter("rift_color", Color("57bcc5") if unlocked else Color("bc9b5b"))
		gate_material.set_shader_parameter("opacity", 0.5 if unlocked else 0.18)

func try_activate(body: Node3D) -> bool:
	if not Orb.is_collector(body) or not is_instance_valid(floor_owner):
		return false
	if kind == Kind.EXIT:
		return floor_owner.try_exit(body)
	if floor_owner.try_collect_key(body):
		visible = false
		set_deferred("monitoring", false)
		queue_free()
		return true
	return false

func _physics_process(_delta: float) -> void:
	# Collect when a guard dies while the player is already overlapping the key.
	if kind == Kind.KEY and is_instance_valid(floor_owner) and not floor_owner.key_collected:
		for body in get_overlapping_bodies():
			if try_activate(body):
				break

func try_companion_collect(body: Node3D) -> bool:
	# An exit always requires the player to enter it intentionally.
	return try_activate(body) if kind == Kind.KEY else false
