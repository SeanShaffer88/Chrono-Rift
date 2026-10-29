extends Area3D
## Healing is never consumed at full HP, whether touched or collected remotely.
const Orb = preload("res://scenes/dungeon/atla_sphere.gd")
const Factory = preload("res://scripts/utilities/primitive_mesh_factory.gd")
var collected := false
var heal_amount := 20
var floor_owner: Node
var pickup_id := ""

func _ready() -> void:
	add_to_group(&"companion_pickups")
	collision_layer = 128
	collision_mask = 2
	monitorable = false
	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.65
	collision.shape = shape
	collision.position.y = 0.6
	add_child(collision)
	var mesh := Factory.create_box(Vector3(0.34, 0.5, 0.34), Color("c85c72"), 0.35)
	mesh.position.y = 0.6
	add_child(mesh)
	var stripe := Factory.create_box(Vector3(0.38, 0.12, 0.38), Color("f5dbc6"))
	stripe.position.y = 0.6
	add_child(stripe)
	body_entered.connect(try_companion_collect)

func try_companion_collect(body: Node3D) -> bool:
	if collected or not Orb.is_collector(body) or body.current_hp >= body.max_hp or heal_amount <= 0:
		return false
	body.heal(heal_amount)
	if is_instance_valid(floor_owner) and not pickup_id.is_empty():
		floor_owner.collected_healing.append(pickup_id)
	collected = true
	hide()
	set_deferred("monitoring", false)
	queue_free()
	return true
