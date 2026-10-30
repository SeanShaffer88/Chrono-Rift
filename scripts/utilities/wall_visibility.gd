extends RefCounted
## The current gameplay camera alone owns the global aperture; no material is mutated here.
static var owner: WeakRef
static func publish(camera: Camera3D,hero: Node3D,settings: Resource,enabled: bool) -> void:
	if not camera.is_current(): return
	if owner==null or owner.get_ref()!=camera: owner=weakref(camera)
	RenderingServer.global_shader_parameter_set("rift_iso_body_a",hero.global_position+Vector3.UP*0.2)
	RenderingServer.global_shader_parameter_set("rift_iso_body_b",hero.global_position+Vector3.UP*1.8)
	RenderingServer.global_shader_parameter_set("rift_iso_camera",camera.global_position)
	RenderingServer.global_shader_parameter_set("rift_iso_right",camera.global_basis.x)
	RenderingServer.global_shader_parameter_set("rift_iso_up",camera.global_basis.y)
	RenderingServer.global_shader_parameter_set("rift_iso_forward",-camera.global_basis.z)
	RenderingServer.global_shader_parameter_set("rift_iso_radius",settings.wall_aperture_radius)
	RenderingServer.global_shader_parameter_set("rift_iso_feather",settings.wall_aperture_feather)
	RenderingServer.global_shader_parameter_set("rift_iso_opacity",settings.wall_minimum_opacity)
	RenderingServer.global_shader_parameter_set("rift_iso_enabled",float(enabled))
static func release(camera: Camera3D) -> void:
	if owner!=null and owner.get_ref()==camera:
		RenderingServer.global_shader_parameter_set("rift_iso_enabled",0.0)
		owner=null
