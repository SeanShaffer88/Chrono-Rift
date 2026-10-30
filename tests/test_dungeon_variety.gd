extends "res://tests/test_harness_template.gd"
const Data=preload("res://scripts/persistence/save_data.gd")
const Store=preload("res://scripts/persistence/save_store.gd")
const Decor=preload("res://scenes/environment/dungeon_landmarks.gd")
const Floor=preload("res://scenes/dungeon/floor_generator.gd")
class CopyFailure extends "res://scripts/persistence/save_recovery.gd":
	func _copy_file(_from: String,_to: String) -> Error: return ERR_CANT_CREATE
class FixtureStore extends "res://scripts/persistence/save_store.gd":
	var fail_write := false
	var fail_recovery := false
	var writes := 0
	func write_save(data: Dictionary) -> Error:
		writes+=1
		if fail_write:
			last_diagnostic=_diagnostic("write_failed","write_temp",ERR_CANT_CREATE)
			return ERR_CANT_CREATE
		return super.write_save(data)
	func start_fresh_with_backup(fresh: Dictionary) -> Dictionary:
		if fail_recovery: return CopyFailure.new(self).run(fresh)
		return super.start_fresh_with_backup(fresh)
class FixtureSession extends "res://scripts/persistence/save_session.gd":
	var selected := -17017
	var selections := 0
	var injected: RefCounted
	func _fresh_seed() -> int:
		selections+=1
		return selected
	func _make_store(path: String) -> RefCounted:
		return injected if injected!=null else super._make_store(path)
var paths: Array[String]=[]
func path_for(label: String) -> String:
	var path := "user://verification-variety-%d-%d-%s.json"%[OS.get_process_id(),Time.get_ticks_usec(),label]
	paths.append(path)
	return path
func dungeon() -> Node:
	var scene=load("res://scenes/dungeon/dungeon_manager.tscn").instantiate()
	root.add_child(scene)
	stop(scene)
	return scene
func stop(scene: Node) -> void:
	scene.get_node("MeleeHero").set_physics_process(false)
	scene.floor_generator.guard.set_physics_process(false)
	for actor: Node in scene.floor_generator.encounters.values(): actor.set_physics_process(false)
func inside_envelope(point: Vector3,records: Array,biome: String) -> bool:
	var low := Vector3(-0.745,0.35,-0.115) if biome=="foundry" else Vector3(-0.81,0.04,-0.11) if biome=="frost" else Vector3(-0.65,0.08,-0.09)
	# Existing foundry collars reach .03+.145=.175; the valve itself reaches .165.
	var high := Vector3(0.745,2.55,0.175) if biome=="foundry" else Vector3(0.81,2.49,0.16) if biome=="frost" else Vector3(0.65,2.4225,0.18)
	for record: Dictionary in records:
		var anchor: Vector2i=record.anchor
		var local := point-Vector3(anchor.x*2,0,anchor.y*2-1.08)
		if local.x>=low.x-0.00001 and local.x<=high.x+0.00001 and local.y>=low.y-0.00001 and local.y<=high.y+0.00001 and local.z>=low.z-0.00001 and local.z<=high.z+0.00001: return true
	return false
func run_assertions() -> void:
	var state=root.get_node("GameState")
	state.reset()
	for seed_value: int in [-2147483648,2147483647]: check(Data.validate(Data.make_fresh_snapshot(seed_value)),"Signed32 boundary fresh seed validates: %s"%seed_value)
	var scene := dungeon()
	var path := path_for("initial-failure")
	var injected := FixtureStore.new(path,Data.validate)
	injected.fail_write=true
	var session := FixtureSession.new()
	session.injected=injected
	root.add_child(session)
	session.start(scene,path)
	stop(scene)
	check(session.selections==1 and injected.writes==1 and scene.dungeon_seed==-17017 and not FileAccess.file_exists(path),"Failed initial write retains one selected fresh expedition in memory")
	injected.fail_write=false
	check(session.flush()==OK and int(injected.read_save().data.dungeon_seed)==-17017 and session.selections==1,"Autosave retry persists the same chosen seed without rerolling")
	session.free()
	scene.free()
	state.reset()
	scene=dungeon()
	session=FixtureSession.new()
	root.add_child(session)
	session.start(scene,path)
	stop(scene)
	check(session.selections==0 and scene.dungeon_seed==-17017 and scene.floor_generator.floor_seed==-17017,"Valid load restores exact base/floor seed without choosing a new run")
	var signature: Array=scene.floor_generator.layout.walkable.keys()
	scene.get_node("MeleeHero").take_damage(999)
	check(scene.retry_floor() and scene.dungeon_seed==-17017 and scene.floor_generator.layout.walkable.keys()==signature,"Actual retry keeps the same seed and layout")
	session.free()
	scene.free()
	# Unsupported files never enter the missing-file path; failed explicit recovery is transactional.
	state.reset()
	scene=dungeon()
	path=path_for("unsupported")
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_string('{"version":3,"marker":"preserve"}')
	file.close()
	var hash_before := FileAccess.get_sha256(path)
	injected=FixtureStore.new(path,Data.validate)
	injected.fail_recovery=true
	session=FixtureSession.new()
	session.injected=injected
	root.add_child(session)
	var live_seed: int=scene.dungeon_seed
	session.start(scene,path)
	check(session.selections==0 and injected.writes==0 and FileAccess.get_sha256(path)==hash_before,"Unsupported existing save selects no seed, performs no fresh write and preserves bytes")
	var result: Dictionary=session.start_fresh_with_backup()
	check(not result.ok and scene.dungeon_seed==live_seed and FileAccess.get_sha256(path)==hash_before,"Real archive-copy failure leaves live expedition seed and original save unchanged")
	if not result.archive_path.is_empty(): DirAccess.remove_absolute(result.archive_path)
	session.free()
	scene.free()
	# Independent decoration cannot consume gameplay randomness or alter layouts.
	var floor := Floor.new()
	floor.generate(1337,1,false)
	var rooms := floor.layout.rooms.duplicate()
	var cells := floor.layout.walkable.duplicate()
	seed(478)
	var expected := randi()
	seed(478)
	var plan := Decor.plan(floor.layout.rooms,cells,1337)
	check(randi()==expected and floor.layout.rooms==rooms and floor.layout.walkable==cells,"Decor planning leaves gameplay RNG, room order and walkable layout unchanged")
	check(plan==Decor.plan(floor.layout.rooms,cells,1337) and plan!=Decor.plan(floor.layout.rooms,cells,1338),"Decor arrangements are seed-stable and vary independently across seeds")
	var anchors := {}
	var safe := plan.size()<=8
	for record: Dictionary in plan:
		safe=safe and not anchors.has(record.anchor) and not cells.has(record.anchor+Vector2i.UP) and posmod(record.anchor.x,3)!=0
		anchors[record.anchor]=true
	check(safe,"Decor anchors are unique exposed north-wall cells away from masonry piers")
	var unsafe_rooms: Array[Rect2i]=[Rect2i(3,3,4,4)]
	check(Decor.plan(unsafe_rooms,{Vector2i(4,2):true,Vector2i(5,2):true},1337).is_empty(),"Unsafe wall anchors are skipped without forced fallback")
	for index in range(0,plan.size()-2,3):
		var kinds := {}
		for offset in 3: kinds[plan[index+offset].motif]=true
		check(kinds.size()==3,"Each complete motif bag includes all three forms")
	for biome: String in ["foundry","frost","overgrown_rail"]:
		var holder := Node3D.new()
		root.add_child(holder)
		var model := Decor.build(holder,floor.layout.rooms,cells,1337,biome)
		var records: Array=model.get_meta("decor_plan")
		var envelope_ok := true
		for point: Vector3 in model.mesh.get_faces(): envelope_ok=envelope_ok and inside_envelope(point,records,biome)
		var details := model.get_node_or_null("ImportedFrostDetails")
		if details!=null:
			for part: MeshInstance3D in details.get_children():
				for corner in 8: envelope_ok=envelope_ok and inside_envelope(part.global_transform*part.mesh.get_aabb().get_endpoint(corner),records,biome)
		check(envelope_ok,"%s static decoration stays inside the previous shallow authored envelope"%biome)
		check(model.get_meta("landmark_count")<=8 and model.find_children("*","CollisionObject3D",true,false).is_empty(),"%s stays within room budget and adds no collision"%biome)
		var ambient := model.get_node_or_null("DungeonAmbient")
		check(ambient==null or ambient.targets.size()<=2,"%s has at most two cached ambient targets"%biome)
		if ambient!=null:
			var children := model.find_children("*","Node",true,false).size()
			var phase_safe := true
			for step in 80:
				ambient._process(0.11)
				for item: Dictionary in ambient.targets:
					for corner in 8: phase_safe=phase_safe and inside_envelope(item.node.global_transform*item.node.mesh.get_aabb().get_endpoint(corner),records,biome)
					if item.mode=="piston": phase_safe=phase_safe and absf(item.node.position.y-item.rest.origin.y)<=0.040001
					elif item.mode=="leaf": phase_safe=phase_safe and absf(item.node.rotation.z)<=deg_to_rad(2.001)
			check(phase_safe and model.find_children("*","Node",true,false).size()==children,"%s ambient motion stays bounded without creating nodes"%biome)
			ambient.time=TAU*10-0.0001
			ambient._process(0.0)
			var before_wrap: Array[Transform3D]=[]
			for item: Dictionary in ambient.targets: before_wrap.append(item.node.transform)
			ambient._process(0.0002)
			var continuous := absf(ambient.time-0.0001)<0.00001
			for index in before_wrap.size():
				var after: Transform3D=ambient.targets[index].node.transform
				continuous=continuous and before_wrap[index].origin.distance_to(after.origin)<0.001 and before_wrap[index].basis.x.distance_to(after.basis.x)<0.001 and before_wrap[index].basis.y.distance_to(after.basis.y)<0.001
			check(continuous,"%s cached target transforms remain continuous across phase wrap"%biome)
			holder.process_mode=Node.PROCESS_MODE_DISABLED
			check(not ambient.can_process(),"%s ambient controller respects owner pause"%biome)
		holder.free()
	floor.free()
	for file_path in paths:
		for suffix: String in ["",".bak",".tmp",".bak.tmp",".recovery.json"]:
			if FileAccess.file_exists(file_path+suffix): DirAccess.remove_absolute(file_path+suffix)
	state.reset()
