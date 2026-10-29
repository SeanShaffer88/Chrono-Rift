extends RefCounted
## Safe sphere sweep plus immediate retraction / eased extension of SpringArm3D.
var hero: Node3D
var probe := SphereShape3D.new()
var manual_time := 0.0
var touch_index := -1
var distance := 6.0
var query := PhysicsShapeQueryParameters3D.new()
const MIN_PITCH := -PI / 3.0
const MAX_PITCH := -35.0 * PI / 180.0
const CLEARANCE := 2.4
const ESCAPE_ANGLES := [45.0,90.0,135.0,180.0]
var preferred_pitch := deg_to_rad(-40.0)
var intended_yaw := 0.0
var rescue_offset := 0.0

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
	preferred_pitch = clampf(hero.spring_arm.rotation.x, MIN_PITCH, MAX_PITCH)
	intended_yaw = hero.camera_pivot.rotation.y

func get_preferred_yaw() -> float:
	return intended_yaw

func restore_view(yaw: float,pitch: float) -> void:
	intended_yaw = yaw
	preferred_pitch = clampf(pitch,MIN_PITCH,MAX_PITCH)
	snap()

func snap() -> void:
	preferred_pitch = clampf(preferred_pitch,MIN_PITCH,MAX_PITCH)
	rescue_offset = 0.0
	hero.camera_pivot.rotation.y = intended_yaw
	hero.spring_arm.rotation.x = preferred_pitch
	hero.camera_pivot.global_position = hero.global_position + Vector3.UP * hero.camera_height
	distance = hero.camera_distance
	update(0.0)

func orbit(yaw: float, pitch: float) -> void:
	intended_yaw = wrapf(intended_yaw+yaw,-PI,PI)
	hero.camera_pivot.rotation.y += yaw
	preferred_pitch = clampf(preferred_pitch + pitch,MIN_PITCH,MAX_PITCH)
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
		intended_yaw = lerp_angle(intended_yaw,target_yaw,1.0-exp(-delta*5.0))
	query.transform.origin = desired
	var preferred_clearance := _safe_length(preferred_pitch,intended_yaw)
	var offset_goal := 0.0
	if preferred_clearance < CLEARANCE:
		offset_goal = _escape_offset(preferred_clearance)
	rescue_offset = offset_goal
	var yaw_goal := intended_yaw+offset_goal
	var blend := 1.0-exp(-delta*8.0)
	hero.camera_pivot.rotation.y = yaw_goal if delta == 0.0 else lerp_angle(hero.camera_pivot.rotation.y,yaw_goal,blend)
	hero.spring_arm.rotation.x = preferred_pitch if delta == 0.0 else clampf(lerp_angle(hero.spring_arm.rotation.x,preferred_pitch,blend),MIN_PITCH,MAX_PITCH)
	# Check the actual interpolated orientation, never only the chosen candidate.
	var safe := _safe_length(hero.spring_arm.rotation.x,hero.camera_pivot.rotation.y)
	distance = safe if safe < distance else lerpf(distance,safe,1.0-exp(-delta*5.0))
	hero.spring_arm.spring_length = maxf(0.0,distance)

func _escape_offset(preferred_clearance: float) -> float:
	var best_offset := 0.0
	var best_clearance := preferred_clearance
	var found_clear := false
	# Probe the previously selected side first when equally small angles work.
	var side := -1.0 if rescue_offset < 0.0 else 1.0
	for degrees: float in ESCAPE_ANGLES:
		for sign_value: float in [side,-side]:
			var candidate := deg_to_rad(degrees)*sign_value
			var clearance := _safe_length(preferred_pitch,intended_yaw+candidate)
			if clearance >= CLEARANCE:
				best_offset = candidate
				best_clearance = clearance
				found_clear = true
				break
			if clearance > best_clearance+0.15:
				best_clearance = clearance
				best_offset = candidate
		if found_clear: break
	# A modest advantage is required to switch sides; discard unsafe stale choices.
	if rescue_offset != 0.0 and best_offset*rescue_offset < 0.0:
		var retained := _safe_length(preferred_pitch,intended_yaw+rescue_offset)
		if retained >= maxf(CLEARANCE,best_clearance-0.35): return rescue_offset
	return best_offset

func _safe_length(pitch: float,yaw: float) -> float:
	# Candidate evaluation mutates only the owned query, not the camera transform.
	query.motion = (Basis(Vector3.UP,yaw)*Basis(Vector3.RIGHT,pitch)).z*hero.camera_distance
	var space := hero.get_world_3d().direct_space_state
	return 0.0 if not space.intersect_shape(query,1).is_empty() else float(space.cast_motion(query)[0])*hero.camera_distance

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
