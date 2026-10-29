extends Node
const Services=preload("res://scripts/utilities/services.gd")
const Menu=preload("res://scenes/ui/character_menu.gd")
var failures := 0
func _ready() -> void: run.call_deferred()
func check(value: bool,label: String) -> void:
	if not value: failures+=1
	print("ENEMY_QA "+("PASS: " if value else "FAIL: ")+label)
func capture(label: String) -> void:
	for frame in 3: await get_tree().process_frame
	print("ENEMY_QA CAPTURE: "+label)
	await get_tree().create_timer(1.1).timeout
func stop_enemies(dungeon: Node) -> void:
	dungeon.floor_generator.guard.set_physics_process(false)
	for enemy: Node3D in dungeon.floor_generator.encounters.values(): enemy.set_physics_process(false)
func lane(floor: Node,cell: Vector2i) -> Vector3:
	for direction in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
		var valid := true
		for distance in range(1,4): valid=valid and floor.layout.walkable.has(cell+direction*distance)
		if valid: return Vector3(direction.x,0,direction.y)
	return Vector3.FORWARD
func frame_actor(hero: Node,actor: Node,heading: Vector3,distance: float=3) -> void:
	hero.position=actor.position+heading*distance+Vector3.UP*0.1
	hero.velocity=Vector3.ZERO
	hero.face_direction(-heading)
	hero._set_lock_target(actor)
	hero.camera_rig.restore_view(atan2(heading.x,heading.z),deg_to_rad(-40))
func run() -> void:
	var state=Services.game_state()
	state.reset()
	var dungeon=load("res://scenes/dungeon/dungeon_manager.tscn").instantiate()
	add_child(dungeon)
	var hero=dungeon.get_node("MeleeHero")
	hero.set_physics_process(false)
	stop_enemies(dungeon)
	check(dungeon.save_session==null,"Isolated encounter QA never loads shipping save")
	check(dungeon.floor_generator.encounters.size()==3,"Deterministic baseline includes all three normal roles")
	var hunter=dungeon.floor_generator.encounters.hunter
	var heading := lane(dungeon.floor_generator,dungeon.floor_generator.encounter_plan.hunter)
	frame_actor(hero,hunter,heading)
	hunter.rotation.y=atan2(-heading.x,-heading.z)
	hunter.target=hero
	hunter._set_state(hunter.State.WINDUP)
	await capture("hunter-windup")
	var start: Vector3=hunter.position
	hero.current_hp=100
	hunter.tick_brain(0.70)
	hunter.set_physics_process(true)
	await get_tree().create_timer(0.45).timeout
	hunter.set_physics_process(false)
	check(hunter.position.distance_to(start)<=2.82 and hunter.committed_heading.dot(heading)>0.999,"Actual Hunter dash stays bounded and committed")
	check(hero.current_hp==90,"Actual Hunter overlap acknowledges exactly one10-damage hit")
	await capture("hunter-recovery")
	var bruiser=dungeon.floor_generator.encounters.bruiser
	heading=Vector3.FORWARD
	frame_actor(hero,bruiser,heading,1.15)
	bruiser.rotation.y=0
	bruiser._set_state(bruiser.State.WINDUP)
	bruiser.target=hero
	frame_actor(hero,bruiser,heading,2.5)
	await capture("bruiser-windup-backstep")
	frame_actor(hero,bruiser,heading,1.15)
	hero._on_weapon_equipped(hero.weapon_inventory.equipped_weapon)
	hero.request_attack()
	hero.tick_combat(0.11)
	hero._on_weapon_hitbox_area_entered(bruiser.get_node("Hurtbox"))
	check(bruiser.current_hp==52 and hero.weapon_hitbox.last_resolved_damage==8 and bruiser.state==bruiser.State.WINDUP,"Bruiser front armor halves ordinary damage once without stagger")
	hero._on_weapon_equipped(hero.weapon_inventory.equipped_weapon)
	hero.position=bruiser.position+Vector3.RIGHT*1.15+Vector3.UP*0.1
	hero.request_attack()
	hero.tick_combat(0.11)
	hero._on_weapon_hitbox_area_entered(bruiser.get_node("Hurtbox"))
	check(bruiser.current_hp==37 and bruiser.state==bruiser.State.STAGGER,"Bruiser flank takes full15 and staggers")
	var sentry=dungeon.floor_generator.encounters.sentry
	heading=lane(dungeon.floor_generator,dungeon.floor_generator.encounter_plan.sentry)
	frame_actor(hero,sentry,heading)
	hero.current_hp=100
	sentry.rotation.y=atan2(-heading.x,-heading.z)
	sentry.target=hero
	sentry._set_state(sentry.State.WINDUP)
	await capture("sentry-aim")
	var wall := StaticBody3D.new()
	wall.collision_layer=1
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size=Vector3(0.35,2,0.35)
	collision.shape=shape
	wall.add_child(collision)
	dungeon.floor_generator.content.add_child(wall)
	wall.position=sentry.position+heading*1.5+Vector3.UP
	sentry.set_physics_process(true)
	await get_tree().create_timer(1.6).timeout
	sentry.set_physics_process(false)
	check(hero.current_hp==100,"Actual Sentry bolt is stopped by nearer masonry collider")
	wall.free()
	sentry.cancel_projectiles()
	sentry._set_state(sentry.State.WINDUP)
	sentry.set_physics_process(true)
	await get_tree().create_timer(1.6).timeout
	sentry.set_physics_process(false)
	check(hero.current_hp==92,"Unblocked Sentry bolt acknowledges one8-damage hit")
	await capture("sentry-recovery")
	state.record_floor_clear(6)
	for id in ["melee_hero","swordsman","riftwarden","battlemage","devourer"]:
		check(state.swap_character(id),"Existing hero remains selectable "+id)
		await capture("hero-"+id)
	for role in ["hunter","bruiser","sentry"]:
		var enemy=dungeon.floor_generator.encounters[role]
		enemy.current_hp=enemy.max_hp
		enemy._set_state(enemy.State.PATROL)
		frame_actor(hero,enemy,Vector3.FORWARD,1.15)
		enemy.rotation.y=0
		hero._on_weapon_equipped(null)
		hero.request_attack()
		hero.tick_combat(0.11)
		hero._on_weapon_hitbox_area_entered(enemy.get_node("Hurtbox"))
		check(enemy.current_hp==0 and hero.weapon_hitbox.last_swallowed,"Devourer swallows normal "+role+" through acknowledged pipeline")
	await capture("devourer-swallow")
	var path="user://verification-encounters-v4-%d.json"%OS.get_process_id()
	dungeon.start_saving(path)
	check(dungeon.save_session.flush()==OK,"Fresh schema4 save flushes encounter deaths")
	dungeon.queue_free()
	await get_tree().process_frame
	state.reset()
	dungeon=load("res://scenes/dungeon/dungeon_manager.tscn").instantiate()
	add_child(dungeon)
	dungeon.start_saving(path)
	hero=dungeon.get_node("MeleeHero")
	hero.set_physics_process(false)
	stop_enemies(dungeon)
	var dead := true
	for enemy: Node3D in dungeon.floor_generator.encounters.values(): dead=dead and not enemy.is_alive()
	check(dead and not dungeon.floor_generator.guard_defeated and state.active_character_id=="devourer" and state.secret_unlocked,"Scene restart keeps encounter deaths independently of key guard and retains secret hero")
	await capture("restored-encounters")
	for number in range(1,4):
		dungeon.floor_number=number
		dungeon._load_floor()
		stop_enemies(dungeon)
		hero.camera_rig.restore_view(0,deg_to_rad(-40))
		check(dungeon.floor_generator.layout.distances_from(dungeon.floor_generator.spawn_cell).size()==dungeon.floor_generator.layout.walkable.size(),"Biome%d routes remain connected"%number)
		await capture("biome-%d"%number)
	print("ENEMY_QA COMPLETE failures="+str(failures))
	if not OS.has_feature("android"):
		var audio=get_tree().root.get_node_or_null("GameState/CombatAudio")
		if audio!=null: audio.queue_free()
		await get_tree().create_timer(0.1).timeout
		get_tree().quit(1 if failures else 0)
