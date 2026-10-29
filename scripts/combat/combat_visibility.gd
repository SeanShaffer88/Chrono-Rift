extends RefCounted
## Environment-only sight checks shared by targeting and acknowledged attacks.
static func clear_between(source: Node3D, target: Node3D, cached_query: PhysicsRayQueryParameters3D = null) -> bool:
	if not is_instance_valid(source) or not is_instance_valid(target) or not source.is_inside_tree() or not target.is_inside_tree():
		return false
	if source.get_world_3d() != target.get_world_3d():
		return false
	var query := cached_query if cached_query != null else PhysicsRayQueryParameters3D.new()
	query.from = source.global_position + Vector3.UP * 0.8
	query.to = target.global_position + Vector3.UP * 0.8
	query.collision_mask = 1
	query.hit_from_inside = true
	return source.get_world_3d().direct_space_state.intersect_ray(query).is_empty()
