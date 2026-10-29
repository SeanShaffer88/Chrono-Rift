extends "res://tests/test_harness_template.gd"
const Paper = preload("res://scripts/utilities/paper_geometry.gd")
const Regions = preload("res://scripts/utilities/dungeon_biomes.gd")
const Floor = preload("res://scenes/dungeon/floor_generator.gd")
const Parts = preload("res://scripts/utilities/landmark_assets.gd")
const Imported = preload("res://scenes/environment/imported_landmarks.gd")
const Landmarks = preload("res://scenes/environment/dungeon_landmarks.gd")
const Assets = preload("res://scripts/utilities/environment_assets.gd")
const Services = preload("res://scripts/utilities/services.gd")

func closed(mesh: Mesh,label: String) -> void:
	var faces := mesh.get_faces()
	var edges := {}
	var valid := not faces.is_empty()
	var volume := 0.0
	for index in range(0,faces.size(),3):
		valid=valid and faces[index].is_finite() and faces[index+1].is_finite() and faces[index+2].is_finite()
		valid=valid and (faces[index+1]-faces[index]).cross(faces[index+2]-faces[index]).length_squared()>0.0000000001
		volume+=faces[index].dot(faces[index+1].cross(faces[index+2]))/6.0
		for side in 3:
			var a := str((faces[index+side]*100000).round())
			var b := str((faces[index+(side+1)%3]*100000).round())
			var key := a+"|"+b if a<b else b+"|"+a
			edges[key]=int(edges.get(key,0))+(1 if a<b else -1)
	for value: int in edges.values(): valid=valid and value==0
	check(valid and volume < -0.0000001,label+" is finite, nondegenerate and closed with balanced outward winding")

func run_assertions() -> void:
	for kind in ["head","hair","torso","taper","panel"]:
		var mesh := Paper.shape(kind)
		closed(mesh,"Folded "+kind)
		check(mesh==Paper.shape(kind) and mesh.get_surface_count()==1 and mesh.get_faces().size()<1500 and mesh.get_aabb().size.z>0.8,"Folded %s caches bounded layered geometry with real depth" % kind)
	var energy := preload("res://scripts/utilities/chain_weapon_visual.gd").make()
	var duplicate := preload("res://scripts/utilities/chain_weapon_visual.gd").make()
	for kind in ["Grip","ForkedProngs","HotInnerEdges"]:
		var part: MeshInstance3D = energy.get_node(kind)
		closed(part.mesh,"Energy sword "+kind)
		check(part.mesh==duplicate.get_node(kind).mesh and part.material_override.transparency==BaseMaterial3D.TRANSPARENCY_DISABLED,"Energy sword %s reuses opaque resources" % kind)
	check(energy.find_children("*","Light3D",true,false).is_empty() and not energy.has_node("LinkedChain"),"Energy sword adds no light or old chain")
	energy.free()
	duplicate.free()
	var factory := Floor.new()
	root.add_child(factory)
	var layout: Dictionary = {}
	for number in range(1,7):
		check(Regions.for_floor(number)==["foundry","frost","overgrown_rail"][(number-1)%3],"Floor %d derives its expected biome" % number)
		check(factory.generate(1337,number,false),"Biome floor %d generates" % number)
		if number==1: layout=factory.layout.walkable.duplicate()
		check(factory.layout.walkable==layout,"Biome choice preserves seeded gameplay layout %d" % number)
	check(Regions.for_floor(-1)=="foundry" and Regions.normalized("untrusted")=="foundry","Invalid biome inputs fall back to Foundry")
	for id: String in Parts.MODELS:
		var biome := "frost" if id in ["valve","piston"] else "overgrown_rail"
		var part := Parts.create(id,biome,Vector3(2,2,2))
		check(part!=null,"Imported %s palette/nested mesh bakes successfully" % id)
		if part==null: continue
		var source: Node3D = Parts.MODELS[id].instantiate()
		var source_size := Assets.bounds(source).size
		var baked_size := part.mesh.get_aabb().size
		check(source_size.distance_to(baked_size)<0.001,"Imported %s preserves all nested bounds before uniform fit" % id)
		var colors: PackedColorArray = part.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
		var unique := {}
		var finite := true
		for color: Color in colors:
			finite=finite and is_finite(color.r) and is_finite(color.g) and is_finite(color.b) and color.a==1
			unique[color]=true
		check(finite and unique.size()>2 and part.mesh.get_surface_count()==1 and part.mesh.get_faces().size()<20000,"Imported %s keeps a finite multi-color palette in a bounded opaque bake" % id)
		var again := Parts.create(id,biome,Vector3.ONE)
		check(part.mesh==again.mesh and part.find_children("*","AnimationPlayer",true,false).is_empty() and part.find_children("*","CollisionObject3D",true,false).is_empty(),"Imported %s caches geometry without animation or physics ownership" % id)
		part.free()
		again.free()
		source.free()
	check(factory.generate(1337,1,true),"Biomechanical actor fixture builds on the real floor")
	var first: Node3D=factory.guard
	first.set_physics_process(false)
	var second: Node3D=factory._create_guard()
	factory.content.add_child(second)
	second.set_physics_process(false)
	check(first._material!=second._material and first._material.vertex_color_use_as_albedo and second._material.vertex_color_use_as_albedo,"Biomechanical guards own independent vertex-color flash materials")
	var untouched: Color=second._material.albedo_color
	first.receive_hit(1,factory)
	first._physics_process(0.01)
	check(first._material.albedo_color==first.flash_color and second._material.albedo_color==untouched,"Hit flash on one biomechanical guard cannot tint another")
	var holder := Node3D.new()
	root.add_child(holder)
	check(Imported.rail_pair(holder,layout),"Distant train pair is accepted beyond the layout")
	var rail := holder.get_node_or_null("DistantRailLandmark")
	if rail!=null:
		var box := Assets.bounds(rail)
		var footprint := Rect2(Vector2(box.position.x,box.position.z),Vector2(box.size.x,box.size.z))
		check(Parts.clear_of_walkable(footprint,layout,7) and box.position.y>2.72,"Complete actual train/plinth/trim bounds clear every walk footprint and original cap")
	check(not Parts.clear_of_walkable(Rect2(Vector2(-1,-1),Vector2(2,2)),{Vector2i.ZERO:true},7),"Footprint guard rejects overlapping placement")
	var frost := Landmarks.build(holder,factory.layout.rooms,layout,1337,"frost")
	var details := frost.get_node_or_null("ImportedFrostDetails")
	check(details!=null and details.get_child_count()==2,"Frost replaces exactly two native indicator details")
	if details!=null:
		for part: MeshInstance3D in details.get_children():
			var box: AABB=part.transform*part.mesh.get_aabb()
			check(posmod(roundi(part.position.x/2),3)!=0,"Frost imported %s anchor avoids the existing masonry pier" % part.name)
			check(box.end.y<=2.60 and maxf(box.size.x,maxf(box.size.y,box.size.z))<=0.20001,"Frost %s stays within the compact shallow machinery envelope" % part.name)
	check(holder.find_children("*","CollisionObject3D",true,false).is_empty(),"Imported landmark ownership adds no collision")
	holder.free()
	factory.free()
	var state := Services.game_state()
	state.reset()
	var hero: Node3D=load("res://scenes/characters/melee_hero.tscn").instantiate()
	root.add_child(hero)
	hero.set_physics_process(false)
	var visual: Node3D=hero.get_node("Visual")
	var shield: MeshInstance3D=visual.get_node("BackShield")
	var index: int=visual.pose_parts.find(shield)
	check(index>=0 and visual.pose_roles[index]==0 and shield.position.z>0.25,"Infiltrator shield is back-mounted on the body pose, not either arm")
	check(shield.find_children("*","CollisionObject3D",true,false).is_empty(),"Back shield has no block or damage collider")
	state.swap_character("swordsman")
	check(not shield.visible,"Shadowblade cannot retain Infiltrator back shield")
	state.swap_character("melee_hero")
	check(shield.visible and state.weapon_inventory.equipped_weapon.weapon_id=="trail_sword","Infiltrator restores back shield and new sword starter")
	hero.free()
	state.reset()
	for pack in ["train","factory"]: check(FileAccess.file_exists("res://assets/kenney/"+pack+"/License.txt"),"Imported %s retains its exact CC0 license" % pack)
