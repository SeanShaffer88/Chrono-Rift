extends "res://tests/test_harness_template.gd"
const Geometry = preload("res://scripts/utilities/hero_geometry.gd")
const Motion = preload("res://scripts/utilities/character_motion.gd")
const Roster = preload("res://data/characters/character_roster.gd")
const Services = preload("res://scripts/utilities/services.gd")

func run_assertions() -> void:
	check(Roster.HEROES.has("riftwarden") and Roster.HEROES.riftwarden.name == "Riftwarden" and not Roster.HEROES.has("rift_warden"), "Riftwarden uses one display word and one internal identifier")
	for kind in ["round","torso","taper","head","hair"]:
		var mesh := Geometry.shape(kind)
		check(mesh == Geometry.shape(kind) and mesh.get_surface_count() == 1, "Faceted %s geometry is cached and single-surface" % kind)
	for kind in ["head","hair"]:
		var mesh := Geometry.shape(kind)
		var arrays := mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var valid := true
		for index in range(0,vertices.size(),3):
			var a := vertices[index]
			var b := vertices[index+1]
			var c := vertices[index+2]
			valid = valid and (b-a).cross(c-a).length_squared() > 0.00000001
			var center := (a+b+c)/3
			var outward := Vector3(center.x-(center.y*0.24 if kind == "hair" else 0.0),0,center.z)
			if absf(normals[index].y) < 0.99: valid = valid and normals[index].dot(outward) > 0
			if is_equal_approx(center.y,-0.5): valid = valid and normals[index].y < -0.99
		check(valid,"%s geometry has outward flat normals, a closed base and no collapsed apex triangles" % kind)
	var weapon := preload("res://scripts/utilities/chain_weapon_visual.gd").make()
	var blade: Mesh = weapon.get_node("CrescentBlade").mesh
	var faces := blade.get_faces()
	var nondegenerate := faces.size() == (31*2+33*2)*3
	for index in range(0,faces.size(),3): nondegenerate = nondegenerate and (faces[index+1]-faces[index]).cross(faces[index+2]-faces[index]).length_squared() > 0.00000001
	check(nondegenerate,"Single crescent has a triangulated front/back and nondegenerate closed edges")
	weapon.free()
	var holder := Node3D.new()
	var bake := preload("res://scripts/utilities/art_mesh.gd").new()
	bake.cutout(PackedVector2Array([Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]),0.2,Transform3D.IDENTITY,Color.WHITE,Color.WHITE)
	var arrays := bake.finish(holder,"WindingProbe").mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var outward := true
	for index in vertices.size(): outward = outward and vertices[index].dot(normals[index]) > 0
	check(outward,"Shared cutout front, back and edge normals point outward under backface culling")
	holder.free()
	var idle := Motion.sample(0,0.5,0,0,1,0,false)
	var run := Motion.sample(6,0.5,0,0,1,0,false)
	var dodge := Motion.sample(0,0,4,0,1,0,false)
	check(idle.stride == 0 and absf(run.stride) > 0.1, "Run stride follows movement and idle plants feet")
	check(dodge.height < -0.1 and dodge.torso.x > 0.3, "Dodge produces compact lowered presentation")
	check(Motion.sample(0,0,0,0,1,1,false).torso.x < idle.torso.x, "Damage generates an independent recoil pose")
	var buffer := {}
	Motion.sample(6,1,0,0,1,0,false,buffer)
	check(buffer.has("torso") and buffer.size() == 6, "Animation can reuse an owned output buffer")
	var state := Services.game_state()
	state.reset()
	var hero: Node3D = load("res://scenes/characters/melee_hero.tscn").instantiate()
	root.add_child(hero)
	hero.set_physics_process(false)
	var visual: Node3D = hero.get_node("Visual")
	var shape: Shape3D = hero.get_node("CollisionShape3D").shape
	var collider: Transform3D = hero.get_node("CollisionShape3D").transform
	var pivot: Transform3D = hero.get_node("Visual/WeaponPivot").transform
	var hitbox: Transform3D = hero.get_node("Visual/WeaponPivot/WeaponHitbox").transform
	var meshes := visual.find_children("*","MeshInstance3D",true,false).size()
	for id: String in Roster.HEROES:
		state.swap_character(id)
		check(hero.character_id == id and hero.current_hp == 100, "Polished %s switch preserves combat actor health" % id)
		for combat_state in [0,1,2,3,4]:
			hero.combat_state = combat_state
			hero.combo_step = 0
			hero._state_time = 0.04
			hero.velocity = Vector3(6,0,0)
			visual._process(0.016)
			check(hero.get_node("Visual/WeaponPivot").transform == pivot and hero.get_node("Visual/WeaponPivot/WeaponHitbox").transform == hitbox, "Cosmetic %s state %d cannot move damage geometry" % [id,combat_state])
		check(hero.get_node("CollisionShape3D").shape == shape and hero.get_node("CollisionShape3D").transform == collider, "Polished %s retains collision dimensions" % id)
		check(visual.find_children("*","MeshInstance3D",true,false).size() == meshes, "Pose updates and switching do not accumulate model nodes")
	hero.combat_state = 0
	hero.combo_step = -1
	hero.velocity = Vector3.ZERO
	visual.reset_motion()
	check(hero.take_damage(7) and visual.recoil == 1, "Accepted damage triggers a local visual reaction")
	visual._process(0.05)
	check(visual.recoil > 0 and visual.recoil < 1, "Hit reaction decays without a gameplay timer")
	check(not hero.take_damage(0), "Rejected damage does not generate another reaction")
	visual.reset_motion()
	check(visual.recoil == 0 and visual.phase == 0, "Character reset clears transient pose state")
	state.swap_character("riftwarden")
	var chain: Node3D = hero.get_node("Visual/WeaponPivot/Blade/ChainBlade")
	check(chain.get_node("LinkedChain").multimesh.instance_count == 8, "Riftwarden keeps eight linked metal chain segments in one batch")
	check(visual.get_node("Mask").visible and not visual.get_node("HairTuft0").visible, "Riftwarden mask and hood replace the shared hair silhouette")
	hero.queue_free()
	await process_frame
	state.reset()
