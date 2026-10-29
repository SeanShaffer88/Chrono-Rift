extends "res://tests/test_harness_template.gd"
const Floor=preload("res://scenes/dungeon/floor_generator.gd")
const Plan=preload("res://scripts/combat/encounter_layout.gd")
const Profiles=preload("res://scripts/combat/enemy_profiles.gd")
const Bolt=preload("res://scripts/combat/enemy_projectile.gd")
const Services=preload("res://scripts/utilities/services.gd")
func wall(at: Vector3,size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer=1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size=size
	shape.shape=box
	body.position=at
	body.add_child(shape)
	root.add_child(body)
	return body
func closed(mesh: Mesh,label: String) -> void:
	var faces := mesh.get_faces()
	var edges := {}
	var valid := not faces.is_empty() and faces.size()<6000
	var volume := 0.0
	for index in range(0,faces.size(),3):
		valid=valid and faces[index].is_finite() and faces[index+1].is_finite() and faces[index+2].is_finite()
		valid=valid and (faces[index+1]-faces[index]).cross(faces[index+2]-faces[index]).length_squared()>0.0000000001
		volume+=faces[index].dot(faces[index+1].cross(faces[index+2]))/6
		for side in 3:
			var a := str((faces[index+side]*100000).round())
			var b := str((faces[index+(side+1)%3]*100000).round())
			var key := a+"|"+b if a<b else b+"|"+a
			edges[key]=int(edges.get(key,0))+(1 if a<b else -1)
	for value: int in edges.values(): valid=valid and value==0
	check(valid and volume<0,label+" closed finite outward bounded geometry")
func run_assertions() -> void:
	var state=Services.game_state()
	state.reset()
	var factory := Floor.new()
	factory.generate(1337,1,false)
	var hero=load("res://scenes/characters/melee_hero.tscn").instantiate()
	root.add_child(hero)
	hero.set_physics_process(false)
	hero.position=Vector3(0,0,-1)
	var bruiser=factory.create_enemy("bruiser",Vector2i.ZERO)
	root.add_child(bruiser)
	bruiser.set_physics_process(false)
	var dummy=factory.create_enemy("guard",Vector2i.ZERO)
	dummy.set_script(preload("res://scenes/characters/training_dummy.gd"))
	root.add_child(dummy)
	dummy.set_physics_process(false)
	for body in [bruiser,dummy]:
		for amount in [0,-5]:
			for swallow in [false,true]:
				var result: Dictionary=body.receive_combat_hit(amount,hero,{},{},swallow)
				check(not result.accepted and result.damage==0 and not result.swallowed and body.current_hp==60,"Public body adapter rejects nonpositive damage before armor/swallow resolution")
	dummy.queue_free()
	check(bruiser.max_hp==60 and not bruiser.is_boss,"Bruiser is a normal60HP encounter")
	hero.weapon_hitbox.set_active(true)
	check(hero.weapon_hitbox.try_hit(bruiser.get_node("Hurtbox"),hero,15)==bruiser and bruiser.current_hp==52 and hero.weapon_hitbox.last_resolved_damage==8 and bruiser.state==bruiser.State.PATROL,"Front armor resolves once with rounded half damage and no stagger")
	hero.weapon_hitbox.set_active(false)
	hero.weapon_hitbox.set_active(true)
	hero.position=Vector3(1,0,0)
	check(hero.weapon_hitbox.try_hit(bruiser.get_node("Hurtbox"),hero,15)==bruiser and bruiser.current_hp==37 and bruiser.state==bruiser.State.STAGGER,"Flank hit deals full damage and staggers")
	bruiser.current_hp=60
	bruiser._set_state(bruiser.State.RECOVERY)
	hero.position=Vector3(0,0,-1)
	hero.weapon_hitbox.set_active(false)
	hero.weapon_hitbox.set_active(true)
	check(hero.weapon_hitbox.try_hit(bruiser.get_node("Hurtbox"),hero,15)==bruiser and bruiser.current_hp==45,"Recovery exposes full ordinary damage")
	bruiser.current_hp=60
	bruiser._set_state(bruiser.State.PATROL)
	hero.weapon_hitbox.set_active(false)
	hero.weapon_hitbox.set_active(true)
	check(hero.weapon_hitbox.try_swallow(bruiser.get_node("Hurtbox"),hero,15)==bruiser and bruiser.current_hp==0 and hero.weapon_hitbox.last_resolved_damage==60 and hero.weapon_hitbox.last_swallowed,"Devourer acknowledged normal swallow bypasses frontal armor")
	bruiser.queue_free()
	var ground := wall(Vector3(0,-0.1,0),Vector3(12,0.2,12))
	var barrier := wall(Vector3(0,1.5,-1.5),Vector3(2,3,0.2))
	var hunter=factory.create_enemy("hunter",Vector2i.ZERO)
	root.add_child(hunter)
	hunter.set_physics_process(false)
	hero.position=Vector3(0,0,-3)
	hunter.target=hero
	hunter._set_state(hunter.State.WINDUP)
	var heading: Vector3=hunter.committed_heading
	hero.position=Vector3(3,0,-3)
	hunter.tick_brain(0.70)
	for frame in 24:
		await physics_frame
		hunter._physics_process(1.0/60)
	check(hunter.committed_heading.is_equal_approx(heading) and hunter.position.z>-1.1 and hunter.position.length()<2.81,"Real Hunter dash keeps committed heading, bounded travel and wall stopping")
	check(hunter.state!=hunter.State.ACTIVE,"Blocked Hunter leaves dash active window")
	hunter.receive_hit(1,hero)
	check(hunter.state==hunter.State.STAGGER and hunter.velocity==Vector3.ZERO,"Damage interrupts Hunter dash/pursuit")
	barrier.free()
	var camera_side := wall(Vector3(1.5,1.4,0),Vector3(0.2,2.8,6))
	var camera_back := wall(Vector3(0,1.4,1.5),Vector3(6,2.8,0.2))
	hero.position=Vector3.ZERO
	hunter.position=Vector3(0,0,-3)
	hunter.rotation.y=PI
	hunter._set_state(hunter.State.WINDUP)
	hunter.tick_brain(0.70)
	hero.camera_rig.restore_view(PI/4,deg_to_rad(-40))
	var camera_safe := true
	for frame in 24:
		await physics_frame
		hunter._physics_process(1.0/60)
		hero.camera_rig.update(1.0/60)
		camera_safe=camera_safe and hero.spring_arm.spring_length<=hero.camera_rig._safe_length(hero.spring_arm.rotation.x,hero.camera_pivot.rotation.y)+0.01 and hero.spring_arm.rotation.x>=deg_to_rad(-60.01) and hero.spring_arm.rotation.x<=deg_to_rad(-34.99)
	check(camera_safe,"Corner camera stays sphere-clear and bounded during real Hunter charge")
	check(hero.current_hp==90,"Real Hunter active overlap deals exactly one10-damage hit")
	camera_side.free()
	camera_back.free()
	hunter.queue_free()
	var sentry=factory.create_enemy("sentry",Vector2i.ZERO)
	root.add_child(sentry)
	sentry.set_physics_process(false)
	sentry.position=Vector3(-3,0,0)
	hero.position=Vector3.ZERO
	hero.current_hp=100
	await physics_frame
	var bolt := Bolt.new()
	bolt.source=sentry
	bolt.heading=Vector3.RIGHT
	root.add_child(bolt)
	bolt.global_position=Vector3(-2,0.9,0)
	bolt.set_physics_process(false)
	bolt.tick_flight(0.5)
	check(bolt.spent and hero.current_hp==92,"Full-segment bolt catches a crossed hurtbox without tunneling")
	bolt.tick_flight(0.5)
	check(hero.current_hp==92,"Spent bolt cannot damage twice")
	await physics_frame
	var blocker := wall(Vector3(-1,1,0),Vector3(0.2,2,2))
	await physics_frame
	bolt=Bolt.new()
	bolt.source=sentry
	bolt.heading=Vector3.RIGHT
	root.add_child(bolt)
	bolt.global_position=Vector3(-2,0.9,0)
	bolt.set_physics_process(false)
	bolt.tick_flight(0.5)
	check(bolt.spent and hero.current_hp==92 and bolt.position.x<0,"Closest wall consumes bolt before player")
	blocker.free()
	await physics_frame
	hero._dodge_cooldown_left=0
	hero.request_dodge()
	bolt=Bolt.new()
	bolt.source=sentry
	bolt.heading=Vector3.RIGHT
	root.add_child(bolt)
	bolt.global_position=Vector3(-2,0.9,0)
	bolt.set_physics_process(false)
	bolt.tick_flight(0.5)
	check(bolt.spent and hero.current_hp==92,"Dodge iframe rejects damage but consumes touching bolt")
	hero.tick_combat(1)
	bolt=Bolt.new()
	bolt.source=sentry
	bolt.heading=Vector3.LEFT
	root.add_child(bolt)
	bolt.global_position=Vector3(-3,0.9,0)
	bolt.set_physics_process(false)
	bolt.tick_flight(5)
	check(bolt.spent and bolt.age<=1.8 and bolt.position.x>=-15.61,"Bolt lifetime and distance remain bounded under a long frame")
	sentry._fire_bolt()
	sentry._fire_bolt()
	sentry._fire_bolt()
	check(sentry.projectiles.size()==2,"Sentry cannot own more than two live bolts")
	var owned: Array=sentry.projectiles.duplicate()
	sentry.receive_hit(30,hero)
	check(sentry.projectiles.is_empty() and owned[0].spent and owned[1].spent,"Sentry death cancels its live bolts")
	sentry.queue_free()
	ground.free()
	hero.queue_free()
	await process_frame
	for seed_value in [1,7,1337,981]:
		var floor := Floor.new()
		root.add_child(floor)
		check(floor.generate(seed_value,2,true),"Role floor generates seed%d"%seed_value)
		var plan: Dictionary=floor.encounter_plan.duplicate()
		check(plan.size()<=3 and floor.encounters.size()<=3,"Role spawn count stays below four including key guard")
		var rooms := {}
		var safe := true
		for role: String in plan:
			var cell: Vector2i=plan[role]
			safe=safe and not floor.layout.rooms[0].has_point(cell) and not [floor.spawn_cell,floor.key_cell,floor.guard_cell,floor.exit_cell].has(cell) and not floor.orb_cells.has(cell)
			for index in floor.layout.rooms.size():
				if floor.layout.rooms[index].has_point(cell):
					safe=safe and not rooms.has(index)
					rooms[index]=true
		check(safe,"Role cells use separate nonspawn rooms and exclude reserved gameplay cells")
		if floor.encounters.has("hunter"): floor.encounters.hunter.receive_hit(40,floor)
		if floor.encounters.has("bruiser"): floor.encounters.bruiser.receive_hit(7,floor)
		var snapshot: Dictionary=floor.progress_snapshot()
		var old_content: Node=floor.content
		floor.generate(seed_value,2,true)
		check(floor.encounter_plan==plan and not is_instance_valid(old_content),"Regeneration is deterministic and frees owned actors")
		floor.restore_progress(snapshot)
		check(floor.progress_snapshot().encounters==snapshot.encounters and not floor.guard_defeated,"Encounter HP/death restores independently of key guard")
		floor.queue_free()
		await process_frame
	var BSP=preload("res://scripts/utilities/bsp_tree.gd")
	for seed_value in [1,7,1337,981]:
		var classic=BSP.new()
		var implicit=BSP.new()
		classic.generate(seed_value,Vector2i(48,48),"classic")
		implicit.generate(seed_value)
		check(classic.walkable==implicit.walkable,"Classic foundry layout preserves existing seeded contract")
		for style in ["frost","overgrown_rail"]:
			var shaped=BSP.new()
			shaped.generate(seed_value,Vector2i(48,48),style)
			check(shaped.distances_from(shaped.rooms[0].get_center()).size()==shaped.walkable.size(),"%s room variation retains every walkable route seed%d"%[style,seed_value])
	var art=preload("res://scripts/utilities/enemy_art.gd")
	for role: String in Profiles.ROLES:
		for biome in ["foundry","frost","overgrown_rail"]:
			var mesh: Mesh=art.role_mesh(role,biome)
			closed(mesh,role+" "+biome)
			check(mesh==art.role_mesh(role,biome) and mesh.get_surface_count()==1,"Role/biome art reuses one bounded opaque surface")
		closed(art.warning_mesh(role),role+" shape warning")
	closed(Bolt.mesh(),"Sentry bolt")
	var Audio=preload("res://scripts/combat/combat_audio.gd")
	var audio=Audio.shared()
	for kind in Audio.KINDS:
		var clip: AudioStreamWAV=Audio.clip(kind)
		check(clip==Audio.clip(kind) and clip.get_length()>0.05 and clip.get_length()<=0.16 and clip.data.size()<8000,"Native cue caches a short bounded PCM buffer")
	await create_timer(0.20).timeout
	var starts: int=audio.started_count
	for index in 20: audio.play_cue("attack")
	check(audio.voices.size()==4 and audio.started_count-starts==4,"Twenty immediate cues start at most four idle voices and drop excess")
	for index in 20: audio.play_cue("hit")
	check(audio.started_count-starts==4,"Busy voices are not stopped or restarted by another burst")
	await create_timer(0.20).timeout
	var completed := true
	for voice: AudioStreamPlayer in audio.voices: completed=completed and not voice.playing
	check(completed,"Short native voices finish naturally")
	audio.play_cue("damage")
	audio.set_muted(true)
	var silent := true
	for voice: AudioStreamPlayer in audio.voices: silent=silent and not voice.playing
	check(silent,"Inspector mute stops all active voices")
	audio.set_muted(false)
	check(not audio.voices[0].playing,"Unmuting cannot replay queued sounds")
	factory.free()
	state.reset()
