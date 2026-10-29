extends Area3D
## Key and exit triggers delegate authoritative progression to their floor.

const Orb := preload("res://scenes/dungeon/atla_sphere.gd")
const Factory := preload("res://scripts/utilities/primitive_mesh_factory.gd")
enum Kind { KEY, EXIT }
var kind: Kind = Kind.KEY
var floor_owner: Node = null

func _ready() -> void:
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
		var mesh := Factory.create_box(Vector3(0.25, 0.65, 0.25), Color(1.0, 0.7, 0.1), 1.0)
		mesh.position.y = 0.9
		add_child(mesh)
	else:
		for x in [-1.0, 1.0]:
			var pillar := Factory.create_box(Vector3(0.3, 2.4, 0.4), Color(0.15, 0.7, 1.0), 1.0)
			pillar.position = Vector3(x, 1.2, 0)
			add_child(pillar)
		var lintel := Factory.create_box(Vector3(2.3, 0.3, 0.4), Color(0.15, 0.7, 1.0), 1.0)
		lintel.position.y = 2.4
		add_child(lintel)
	body_entered.connect(try_activate)

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
