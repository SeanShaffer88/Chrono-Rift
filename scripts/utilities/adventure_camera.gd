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
var body_points: Array[Vector3] = []
var body_ray := PhysicsRayQueryParameters3D.new()
var search_wait := 0.0
var clear_streak := 0
var was_blocked := false
var rescue_episode := false
var profile_revision := -1
var searches := 0
var candidate_count := 0
var body_ray_count := 0
var profile_warning := false

func _init(owner: Node3D) -> void:
	hero = owner
	probe.radius = 0.24
	query.shape = probe
	query.collision_mask = 1
	query.margin = 0.02
	body_ray.collision_mask=1
	body_ray.collide_with_areas=false
	body_ray.collide_with_bodies=true
	body_ray.hit_from_inside=true
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
	search_wait=0.0
	clear_streak=0
	was_blocked=false
	rescue_episode=false
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
	search_wait=maxf(0.0,search_wait-delta)
	var visual: Node3D=hero.get_node("Visual")
	var revision: int=visual.camera_profile_revision
	if revision!=profile_revision:
		profile_revision=revision
		search_wait=0.0
		clear_streak=0
		was_blocked=false
		rescue_episode=false
	var has_body: bool=visual.write_camera_probes(body_points)
	if not has_body and not profile_warning:
		push_warning("Camera body profile unavailable; retaining collision safety")
		profile_warning=true
	if has_body:
		for index in 4: body_points[index].y=maxf(body_points[index].y,hero.global_position.y+0.02)
	var actual_length: float=hero.camera_pivot.global_position.distance_to(hero.camera.global_position)
	var actual := _visibility(hero.camera_pivot.rotation.y,hero.spring_arm.rotation.x,actual_length,has_body,hero.camera.global_position)
	var blocked: bool=not actual.full
	# Only the first blocked edge bypasses the timer. Drag deltas never reset it.
	if delta==0.0 or ((blocked or rescue_offset!=0.0 or rescue_episode) and (search_wait<=0.0 or (blocked and not rescue_episode))):
		rescue_episode=true
		rescue_offset=_select_offset(has_body)
		search_wait=0.1
	if rescue_offset==0.0 and not blocked and clear_streak>=3: rescue_episode=false
	was_blocked=blocked
	var offset_goal := rescue_offset
	var yaw_goal := intended_yaw+offset_goal
	var blend := 1.0-exp(-delta*8.0)
	hero.camera_pivot.rotation.y = yaw_goal if delta == 0.0 else lerp_angle(hero.camera_pivot.rotation.y,yaw_goal,blend)
	hero.spring_arm.rotation.x = preferred_pitch if delta == 0.0 else clampf(lerp_angle(hero.spring_arm.rotation.x,preferred_pitch,blend),MIN_PITCH,MAX_PITCH)
	# Check the actual interpolated orientation, never only the chosen candidate.
	var safe := _safe_length(hero.spring_arm.rotation.x,hero.camera_pivot.rotation.y)
	distance = safe if safe < distance else lerpf(distance,safe,1.0-exp(-delta*5.0))
	hero.spring_arm.spring_length = maxf(0.0,distance)

func _visibility(yaw: float,pitch: float,length: float,has_body: bool,actual_position: Variant=null) -> Dictionary:
	var lower := 0
	var torso := 0
	if has_body:
		body_ray.from=hero.camera_pivot.global_position+(Basis(Vector3.UP,yaw)*Basis(Vector3.RIGHT,pitch)).z*length
		if actual_position is Vector3: body_ray.from=actual_position
		for index in 6:
			body_ray.to=body_points[index]
			body_ray_count+=1
			if hero.get_world_3d().direct_space_state.intersect_ray(body_ray).is_empty():
				if index<4: lower+=1
				else: torso+=1
	return {"full":length>=CLEARANCE and (not has_body or lower+torso==6),"lower":lower,"torso":torso,"length":length}

func _select_offset(has_body: bool) -> float:
	searches+=1
	candidate_count=0
	var best: Dictionary={}
	var preferred: Dictionary={}
	var incumbent: Dictionary={}
	var side := -1.0 if rescue_offset<0.0 else 1.0
	for angle: float in [0.0,45.0*side,-45.0*side,90.0*side,-90.0*side,135.0*side,-135.0*side,180.0]:
		var offset := deg_to_rad(angle)
		var length := _safe_length(preferred_pitch,intended_yaw+offset)
		var result := _visibility(intended_yaw+offset,preferred_pitch,length,has_body)
		result.offset=offset
		candidate_count+=1
		if angle==0.0: preferred=result
		if absf(wrapf(offset-rescue_offset,-PI,PI))<0.001: incumbent=result
		if best.is_empty() or _better(result,best): best=result
	clear_streak=clear_streak+1 if preferred.full else 0
	if rescue_offset!=0.0 and preferred.full and clear_streak<3 and not incumbent.is_empty() and incumbent.full:
		return rescue_offset
	return float(best.offset)

func _better(a: Dictionary,b: Dictionary) -> bool:
	if a.full!=b.full: return a.full
	if not a.full:
		if a.lower!=b.lower: return a.lower>b.lower
		if a.torso!=b.torso: return a.torso>b.torso
		if absf(a.length-b.length)>0.01: return a.length>b.length
	if absf(absf(a.offset)-absf(b.offset))>0.001: return absf(a.offset)<absf(b.offset)
	if a.offset*rescue_offset>0.0 and b.offset*rescue_offset<=0.0: return true
	return a.length>b.length+0.01

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
