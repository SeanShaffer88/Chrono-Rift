extends SceneTree
var output := ""
var viewport: SubViewport
var hero: Node3D

func _init() -> void:
	_run.call_deferred()

func capture(label: String) -> void:
	for frame in 2: await process_frame
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png(output.path_join(label + ".png"))

func _run() -> void:
	create_timer(60).timeout.connect(func(): quit(1))
	await process_frame
	var args := OS.get_cmdline_user_args()
	output = ProjectSettings.globalize_path("res://../outputs/character-polish") if args.is_empty() else args[0]
	DirAccess.make_dir_recursive_absolute(output)
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280,720)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var world := Node3D.new()
	viewport.add_child(world)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("24343c")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("b7cad0")
	environment.environment.ambient_light_energy = 0.6
	world.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40,-25,0)
	light.light_energy = 0.8
	world.add_child(light)
	hero = load("res://scenes/characters/melee_hero.tscn").instantiate()
	world.add_child(hero)
	hero.set_physics_process(false)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.fov = 37
	var state := root.get_node("GameState")
	for id in ["melee_hero","swordsman","riftwarden","battlemage","devourer"]:
		if id=="devourer": state.record_floor_clear(6)
		state.swap_character(id)
		var focus := Vector3(0,1.30 if id=="battlemage" else 1.05,0)
		hero.face_direction(Vector3.FORWARD)
		hero.current_hp = 100
		hero.velocity = Vector3.ZERO
		camera.position = Vector3(2.7,2.15,-4.6)
		camera.look_at(focus,Vector3.UP)
		camera.make_current()
		await capture(id + "-idle")
		if id=="devourer":
			hero.get_node("Visual").swallow_cue()
			await capture(id+"-swallow")
		camera.position.z = 4.6
		camera.look_at(focus,Vector3.UP)
		await capture(id + "-back")
		camera.position=Vector3(4.6,2.15,0)
		camera.look_at(focus,Vector3.UP)
		await capture(id+"-side")
		camera.position=Vector3(2.7,2.15,-4.6)
		camera.position.z = -4.6
		camera.look_at(focus,Vector3.UP)
		hero.velocity = Vector3(6,0,0)
		await capture(id + "-run")
		hero.velocity = Vector3.ZERO
		hero.request_attack()
		hero.tick_combat(0.05)
		await capture(id + "-windup")
		hero.tick_combat(0.08)
		await capture(id + "-attack")
		hero.tick_combat(1.0)
		hero._dodge_cooldown_left = 0
		hero.request_dodge()
		await capture(id + "-dodge")
		hero.tick_combat(1.0)
		hero.take_damage(7)
		await capture(id + "-recoil")
	quit()
