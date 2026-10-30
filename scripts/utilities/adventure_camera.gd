extends RefCounted
## Fixed gameplay framing. Lock-on changes combat facing, never the view.
const SETTINGS=preload("res://data/camera/isometric_view_settings.tres")
const Visibility=preload("res://scripts/utilities/wall_visibility.gd")
var hero: Node3D
var preferred_pitch := deg_to_rad(-55.0)
var touch_index := -1
var distance := 14.0
var view_basis := Basis.IDENTITY
var wall_bindings: Array[Node]=[]
var body_points: Array[Vector3]=[]
var body_ray := PhysicsRayQueryParameters3D.new()
var active := true
var blocked := false
var ray_count := 0
var visual: Node3D

func _init(owner: Node3D) -> void:
	hero=owner
	visual=hero.get_node("Visual")
	body_ray.collision_mask=1
	body_ray.collide_with_bodies=true
	body_ray.collide_with_areas=false
	body_ray.hit_from_inside=true
	preferred_pitch=deg_to_rad(SETTINGS.pitch_degrees)
	view_basis=Basis(Vector3.UP,deg_to_rad(SETTINGS.yaw_degrees))*Basis(Vector3.RIGHT,preferred_pitch)
	distance=SETTINGS.follow_distance
	hero.camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	hero.camera.keep_aspect=Camera3D.KEEP_HEIGHT
	hero.camera.size=SETTINGS.orthographic_size
	hero.camera.near=0.08
	# Disable perspective arm retraction without changing any world collision.
	hero.spring_arm.collision_mask=0
	hero.spring_arm.spring_length=distance
	hero.spring_arm.shape=null
	snap()

func get_preferred_yaw() -> float:
	return deg_to_rad(SETTINGS.yaw_degrees)

func restore_view(_yaw: float,_pitch: float) -> void:
	# Version-4 fields remain readable; the fixed view is intentionally authoritative.
	snap()

func snap() -> void:
	touch_index=-1
	hero.camera_pivot.global_position=hero.global_position+Vector3.UP*hero.camera_height
	update(0.0)

func orbit(_yaw: float,_pitch: float) -> void:
	pass

func input(_event: InputEvent) -> void:
	pass

func update(delta: float) -> void:
	var anchor: Vector3=hero.global_position+Vector3.UP*hero.camera_height
	var current: Vector3=hero.camera_pivot.global_position
	if delta==0.0 or current.distance_to(anchor)>4.0: current=anchor
	else: current=current.lerp(anchor,1.0-exp(-delta*SETTINGS.follow_rate))
	hero.camera_pivot.global_transform=Transform3D(Basis(Vector3.UP,get_preferred_yaw()),current)
	hero.spring_arm.rotation=Vector3(preferred_pitch,0,0)
	hero.spring_arm.spring_length=distance
	hero.camera.position=Vector3(0,0,distance)
	_update_visibility()

func set_wall_bindings(value: Array) -> void:
	for binding in wall_bindings:
		if is_instance_valid(binding): binding.set_active(false)
	wall_bindings.assign(value)
	blocked=false

func set_active(value: bool) -> void:
	active=value
	if not value:
		for binding in wall_bindings:
			if is_instance_valid(binding): binding.set_active(false)
		Visibility.release(hero.camera)
	else: snap()

func _update_visibility() -> void:
	if not active or not hero.camera.is_current(): return
	blocked=false
	if SETTINGS.wall_fading_enabled and not wall_bindings.is_empty() and visual.write_camera_probes(body_points):
		for index in body_points.size():
			body_ray.to=body_points[index]
			if index<4: body_ray.to.y=maxf(body_ray.to.y,hero.global_position.y+0.02)
			body_ray.from=hero.camera.project_ray_origin(hero.camera.unproject_position(body_ray.to))
			ray_count+=1
			if not hero.get_world_3d().direct_space_state.intersect_ray(body_ray).is_empty():
				blocked=true
				break
	for binding in wall_bindings:
		if is_instance_valid(binding): binding.set_active(blocked)
	Visibility.publish(hero.camera,hero,SETTINGS,blocked)

func ground_direction(input_value: Vector2) -> Vector3:
	var magnitude := minf(input_value.length(),1.0)
	if magnitude<0.01: return Vector3.ZERO
	var back := Vector3(view_basis.z.x,0,view_basis.z.z).normalized()
	var projected_scale := maxf(0.01,absf(view_basis.y.dot(back)))
	var world := view_basis.x*input_value.x+back*(input_value.y/projected_scale)
	return world.normalized()*magnitude
