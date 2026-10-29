extends Node3D
## Small cosmetic follower with conservative, authoritative pickup delegation.
const Factory = preload("res://scripts/utilities/primitive_mesh_factory.gd")
const Orb = preload("res://scenes/dungeon/atla_sphere.gd")
const COLLECTION_RADIUS := 3.0
var hero: CharacterBody3D
var elapsed := 0.0
var scan_left := 0.0
var spark: MeshInstance3D

func _ready() -> void:
	name = "CollectorCompanion"
	top_level = true
	global_position = hero.global_position + Vector3(1.0, 1.3, 0.4)
	var core := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.13
	sphere.height = 0.26
	sphere.radial_segments = 12
	sphere.rings = 6
	core.mesh = sphere
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	core.material_override = preload("res://assets/shaders/companion_energy.tres")
	add_child(core)
	for index in 2:
		var arc := MeshInstance3D.new()
		var ring := TorusMesh.new()
		ring.inner_radius = 0.17
		ring.outer_radius = 0.184
		ring.rings = 12
		ring.ring_segments = 4
		arc.mesh = ring
		arc.rotation = Vector3(0.7 + index, 0, 0.4)
		arc.material_override = Factory.get_shared_material(Color("b32c4d"), 0.5, 1.0)
		add_child(arc)
	spark = MeshInstance3D.new()
	spark.material_override = Factory.get_shared_material(Color("ee536b"), 0.5, 1.3)
	add_child(spark)
	_update_spark()

func _physics_process(delta: float) -> void:
	if not is_instance_valid(hero):
		return
	visible = hero.is_alive()
	if not visible:
		return
	elapsed += delta
	var offset := Vector3(1.0, 1.3 + sin(elapsed * 3.0) * 0.08, 0.4)
	global_position = global_position.lerp(hero.global_position + offset, 1.0 - exp(-delta * 8.0))
	rotation.y += delta * 1.5
	scan_left -= delta
	if scan_left <= 0.0:
		scan_left = 0.15
		_update_spark()
		scan_pickups()

func _update_spark() -> void:
	var lines := ImmediateMesh.new()
	lines.surface_begin(Mesh.PRIMITIVE_LINES)
	var shift := sin(elapsed * 29.0) * 0.04
	var points := [Vector3(-0.21, 0.03, 0), Vector3(-0.11, 0.14 + shift, 0.03), Vector3(-0.08, 0.04, 0.05), Vector3(0.02, 0.2, 0)]
	for index in points.size() - 1:
		lines.surface_add_vertex(points[index])
		lines.surface_add_vertex(points[index + 1])
	lines.surface_end()
	spark.mesh = lines

func can_reach(pickup: Node3D) -> bool:
	if not is_instance_valid(hero) or not Orb.is_collector(hero) or not is_instance_valid(pickup):
		return false
	if pickup.is_queued_for_deletion() or pickup.get_world_3d() != get_world_3d():
		return false
	if hero.global_position.distance_to(pickup.global_position) > COLLECTION_RADIUS:
		return false
	var ray := PhysicsRayQueryParameters3D.create(hero.global_position + Vector3.UP * 0.8, pickup.global_position + Vector3.UP * 0.8, 1)
	return get_world_3d().direct_space_state.intersect_ray(ray).is_empty()

func scan_pickups() -> int:
	var count := 0
	for pickup: Node in get_tree().get_nodes_in_group(&"companion_pickups"):
		if pickup is Node3D and pickup.has_method("try_companion_collect") and can_reach(pickup):
			if pickup.try_companion_collect(hero):
				count += 1
	return count
