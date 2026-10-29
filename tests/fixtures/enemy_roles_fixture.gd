extends SceneTree
class Target extends Node3D:
	func is_alive() -> bool: return true
var viewport: SubViewport
var output := ""
func _init() -> void: run.call_deferred()
func capture(label: String) -> void:
	for frame in 3: await process_frame
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png(output.path_join(label+".png"))
func run() -> void:
	output=ProjectSettings.globalize_path("res://../outputs/enemy-role-native")
	DirAccess.make_dir_recursive_absolute(output)
	viewport=SubViewport.new()
	viewport.size=Vector2i(1280,720)
	viewport.own_world_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var world := Node3D.new()
	viewport.add_child(world)
	var environment := WorldEnvironment.new()
	environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_COLOR
	environment.environment.background_color=Color("24343c")
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color=Color("b7cad0")
	environment.environment.ambient_light_energy=0.6
	world.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees=Vector3(-40,-25,0)
	light.light_energy=0.8
	world.add_child(light)
	var ground := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size=Vector3(12,0.10,16)
	ground.mesh=mesh
	ground.position.y=-0.05
	ground.material_override=preload("res://scripts/utilities/paper_geometry.gd").material(Color("6c7066"))
	world.add_child(ground)
	var camera := Camera3D.new()
	camera.fov=40
	world.add_child(camera)
	camera.position=Vector3(3.2,2.8,-5.2)
	camera.look_at(Vector3(0,0.9,0))
	camera.make_current()
	var target := Target.new()
	target.add_to_group("players")
	world.add_child(target)
	target.position=Vector3(0,0,-3)
	var factory := preload("res://scenes/dungeon/floor_generator.gd").new()
	factory.generate(1337,1,false)
	for role in ["guard","hunter","bruiser","sentry"]:
		var actor=factory.create_enemy(role,Vector2i.ZERO)
		world.add_child(actor)
		actor.set_physics_process(false)
		actor.target=target
		await capture(role+"-idle")
		actor._set_state(actor.State.WINDUP)
		actor.tick_brain(float(actor.profile.windup)*0.5)
		await capture(role+"-windup")
		actor.queue_free()
		await process_frame
	factory.free()
	quit()
