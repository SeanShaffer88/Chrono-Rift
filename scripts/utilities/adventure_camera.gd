extends RefCounted
## Safe sphere sweep plus immediate retraction / eased extension of SpringArm3D.
var hero: Node3D
var probe := SphereShape3D.new()
var manual_time := 0.0
var touch_index := -1
var distance := 6.0
var query := PhysicsShapeQueryParameters3D.new()
var preferred_pitch := deg_to_rad(-28.0)

func _init(owner: Node3D) -> void:
	hero = owner
	probe.radius = 0.24
	query.shape = probe
	query.collision_mask = 1
	query.margin = 0.02
	hero.spring_arm.shape = probe
	hero.spring_arm.margin = 0.08
	hero.camera.near = 0.08
	distance = hero.camera_distance
	preferred_pitch = hero.spring_arm.rotation.x

func snap() -> void:
	hero.camera_pivot.global_position = hero.global_position + Vector3.UP * hero.camera_height
	distance = hero.camera_distance
	update(0.0)

func orbit(yaw: float, pitch: float) -> void:
	hero.camera_pivot.rotation.y += yaw
	preferred_pitch = clampf(preferred_pitch + pitch, deg_to_rad(-55), deg_to_rad(-12))
	hero.spring_arm.rotation.x = preferred_pitch
	manual_time = 0.8

func update(delta: float) -> void:
	manual_time = maxf(0.0, manual_time - delta)
	var anchor: Vector3 = hero.global_position + Vector3.UP * hero.camera_height
	var space := hero.get_world_3d().direct_space_state
	if is_instance_valid(hero.lock_target):
		# A small shoulder offset keeps the enemy readable beside the hero.
		query.transform = Transform3D(Basis.IDENTITY, anchor)
		query.motion = hero.camera_pivot.global_basis.x * 0.6
		anchor += query.motion * float(space.cast_motion(query)[0])
	var current: Vector3 = hero.camera_pivot.global_position
	var desired := current.lerp(anchor, 1.0 - exp(-delta * 16.0))
	if current.distance_to(anchor) > 4.0 or delta == 0.0:
		desired = anchor
	query.transform = Transform3D(Basis.IDENTITY, current)
	query.motion = desired - current
	if not space.intersect_shape(query, 1).is_empty() or space.cast_motion(query)[0] < 1.0:
		desired = anchor
	hero.camera_pivot.global_position = desired
	if is_instance_valid(hero.lock_target) and manual_time == 0.0:
		var direction: Vector3 = hero.lock_target.global_position - hero.camera_pivot.global_position
		var target_yaw := atan2(-direction.x, -direction.z)
		hero.camera_pivot.rotation.y = lerp_angle(hero.camera_pivot.rotation.y, target_yaw, 1.0 - exp(-delta * 5.0))
	query.transform.origin = desired
	var base_distance := _safe_length(preferred_pitch)
	var pitch_goal := preferred_pitch
	# A wall immediately behind the player otherwise fills the view with their head.
	# Raise the viewing angle over low dungeon walls, retaining manual pitch preference.
	if base_distance < 2.4 or (hero.spring_arm.rotation.x < preferred_pitch - 0.02 and base_distance < 3.2):
		var best := base_distance
		for angle in [-45.0, -60.0, -72.0, -82.0]:
			if base_distance < 1.6 and angle > -72.0:
				continue
			var candidate := minf(preferred_pitch, deg_to_rad(angle))
			var candidate_distance := _safe_length(candidate)
			if candidate_distance > best + 0.15:
				best = candidate_distance
				pitch_goal = candidate
			if best > 4.0:
				break
	hero.spring_arm.rotation.x = pitch_goal if delta == 0.0 else lerp_angle(hero.spring_arm.rotation.x, pitch_goal, 1.0 - exp(-delta * 12.0))
	var safe := _safe_length(hero.spring_arm.rotation.x)
	# Never ease through an obstacle; ease only when space opens up again.
	distance = safe if safe < distance else lerpf(distance, safe, 1.0 - exp(-delta * 5.0))
	hero.spring_arm.spring_length = maxf(0.0, distance)

func _safe_length(pitch: float) -> float:
	query.motion = (hero.camera_pivot.global_basis * Basis(Vector3.RIGHT, pitch)).z * hero.camera_distance
	var space := hero.get_world_3d().direct_space_state
	return 0.0 if not space.intersect_shape(query, 1).is_empty() else float(space.cast_motion(query)[0]) * hero.camera_distance

func input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.index == touch_index and (not event.pressed or event.canceled):
			touch_index = -1
		elif event.pressed and not event.canceled and touch_index == -1:
			var viewport_size := hero.get_viewport().get_visible_rect().size
			if event.position.x > viewport_size.x * 0.5 and event.position.y > 100:
				touch_index = event.index
	elif event is InputEventScreenDrag and event.index == touch_index:
		orbit(-event.relative.x * 0.005, -event.relative.y * 0.004)
		hero.get_viewport().set_input_as_handled()
