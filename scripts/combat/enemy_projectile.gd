extends Node3D
## One straight bolt. Floor-owned lifetime; a full segment query prevents tunneling.
const Bake=preload("res://scripts/utilities/art_mesh.gd")
const Paper=preload("res://scripts/utilities/paper_geometry.gd")
static var _mesh: Mesh
var source: Node3D
var heading := Vector3.FORWARD
var age := 0.0
const SPEED := 7.0
const LIFETIME := 1.8
const DAMAGE := 8
var query := PhysicsRayQueryParameters3D.new()
var spent := false

static func mesh() -> Mesh:
	if _mesh==null:
		var bake := Bake.new()
		bake.box(Vector3(0.11,0.11,0.28),Vector3.ZERO,Color("e5ab57"))
		var holder := Node3D.new()
		_mesh=bake.finish(holder,"Bolt").mesh
		holder.free()
	return _mesh

func _ready() -> void:
	var visual := MeshInstance3D.new()
	visual.mesh=mesh()
	visual.material_override=Paper.material(Color.WHITE)
	visual.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(visual)
	query.collision_mask=1|16
	query.collide_with_areas=true
	query.collide_with_bodies=true
	query.hit_from_inside=true
	if heading.length_squared()>0.0001: look_at(global_position+heading,Vector3.UP)

func _physics_process(delta: float) -> void:
	tick_flight(delta)

func tick_flight(delta: float) -> void:
	if spent: return
	if not is_instance_valid(source) or not source.is_inside_tree() or not source.is_alive():
		finish()
		return
	var travel_time := minf(maxf(delta,0),maxf(0,LIFETIME-age))
	query.from=global_position
	query.to=global_position+heading*SPEED*travel_time
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	age+=travel_time
	if not hit.is_empty():
		global_position=hit.position
		# A bolt is consumed by the first environment/hurtbox contact, even a dodge.
		spent=true
		var collider: Node=hit.collider
		if collider is Area3D and collider.has_method("receive_weapon_hit"):
			collider.receive_weapon_hit(DAMAGE,source,{}, {})
		queue_free()
		return
	global_position=query.to
	if age>=LIFETIME: finish()

func finish() -> void:
	spent=true
	queue_free()
