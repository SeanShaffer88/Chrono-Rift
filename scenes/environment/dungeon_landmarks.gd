extends RefCounted
const Imported = preload("res://scenes/environment/imported_landmarks.gd")
const Bake = preload("res://scripts/utilities/art_mesh.gd")
const COPPER := Color("926346")
const BRASS := Color("c1a66c")
const Ambient=preload("res://scenes/environment/dungeon_ambient.gd")
static var valve_mesh: Mesh
static var leaf_mesh: Mesh
static var moving_material: StandardMaterial3D

static func _shuffle(values: Array,rng: RandomNumberGenerator) -> void:
	for index in range(values.size()-1,0,-1):
		var other := rng.randi_range(0,index)
		var saved: Variant=values[index]
		values[index]=values[other]
		values[other]=saved

static func plan(rooms: Array[Rect2i],walkable: Dictionary,seed_value: int) -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.seed=seed_value+41033
	var order: Array=rooms.duplicate()
	_shuffle(order,rng)
	var bag: Array=[]
	var records: Array[Dictionary]=[]
	var previous := -1
	for room: Rect2i in order:
		if records.size()>=8: break
		var candidates: Array=[]
		for offset in range(1,room.size.x-1):
			var cell := room.position+Vector2i(offset,0)
			if not walkable.has(cell+Vector2i.UP) and posmod(cell.x,3)!=0: candidates.append(cell)
		if candidates.is_empty(): continue
		_shuffle(candidates,rng)
		if bag.is_empty():
			bag=[0,1,2]
			_shuffle(bag,rng)
			if bag.back()==previous:
				var saved: int=bag[0]
				bag[0]=bag[2]
				bag[2]=saved
		var motif: int=bag.pop_back()
		records.append({"anchor":candidates[0],"motif":motif,"phase":rng.randf()*TAU})
		previous=motif
	return records

static func build(parent: Node3D, rooms: Array[Rect2i], walkable: Dictionary, seed_value: int,biome: String = "foundry") -> Node3D:
	var bake := Bake.new()
	var count := 0
	var frost_details := 0
	var ambient := Ambient.new()
	ambient.name="DungeonAmbient"
	var imported := Node3D.new()
	imported.name="ImportedFrostDetails"
	var records := plan(rooms,walkable,seed_value)
	for record: Dictionary in records:
		var anchor: Vector2i=record.anchor
		var motif: int=record.motif
		var index := count
		count += 1
		bake.frame = Transform3D(Basis.IDENTITY, Vector3(anchor.x*2,0,anchor.y*2-1.08))
		if biome == "frost":
			if motif==1:
				bake.box(Vector3(1.05,1.1,0.18),Vector3(0,1.1,0),Color("719ca4"))
				bake.box(Vector3(1.1,0.12,0.22),Vector3(0,1.7,0),Color("e3e7d9"))
				for side in [-1,1]: bake.box(Vector3(0.12,0.35,0.04),Vector3(side*0.25,1.15,0.12),Color("d8a252"))
				continue
			if motif==2:
				for side in [-1,1]:
					bake.pipe(Vector3(side*0.45,0.45,0.02),Vector3(side*0.45,2.25,0.02),0.075,Color("719ca4"))
					bake.box(Vector3(0.25,0.12,0.22),Vector3(side*0.45,2.25,0),Color("e3e7d9"))
				continue
			var replaced := false
			if frost_details<2:
				replaced=Imported.frost_detail(imported,bake.frame.origin,"valve" if frost_details==0 else "piston")
				frost_details+=1
				if replaced and frost_details==2: ambient.add_target(imported.get_child(imported.get_child_count()-1),"piston",record.phase)
			# Buried heater/cabinet and frosted pipe loop, fixed to the wall.
			bake.box(Vector3(1.25,1.15,0.18),Vector3(0,0.7,0),Color("719ca4"))
			bake.box(Vector3(1.3,0.12,0.22),Vector3(0,1.32,0),Color("e3e7d9"))
			for side in [-1,1]:
				bake.pipe(Vector3(side*0.72,0.4,0.03),Vector3(side*0.72,2.4,0.03),0.09,Color("cbded8"))
				if not replaced: bake.box(Vector3(0.12,0.45,0.04),Vector3(side*0.25,0.82,0.12),Color("d8a252"))
			bake.box(Vector3(0.65,0.22,0.22),Vector3(0,0.15,0.05),Color("dce4da"))
		elif biome == "overgrown_rail":
			if motif==2:
				bake.box(Vector3(1.1,1.15,0.16),Vector3(0,1.15,0),Color("795d47"))
				bake.pipe(Vector3(0,1.2,0.02),Vector3(0,1.2,0.18),0.3,Color("424b43"))
				bake.box(Vector3(0.8,0.16,0.14),Vector3(0,1.95,0),Color("c4c6a6"))
				continue
			# Station panel, rusted engine housing and paper vines, inside solid edge.
			bake.box(Vector3(1.3,0.85,0.18),Vector3(0,0.55,0),Color("795d47"))
			if motif==0:
				for wheel in [-0.43,0.43]: bake.pipe(Vector3(wheel,0.3,-0.04),Vector3(wheel,0.3,0.18),0.22,Color("424b43"))
			bake.box(Vector3(0.8,0.26,0.14),Vector3(0,1.95,0),Color("c4c6a6"))
			for vine in 3:
				bake.beam(Vector3(-0.5+vine*0.42,2.4,0.1),Vector3(-0.4+vine*0.36,1.15,0.1),0.045,Color("6c8656"))
				if motif==0 or ambient.targets.size()>=2:
					for row in 3: bake.box(Vector3(0.2,0.12,0.025),Vector3(-0.5+vine*0.42,2.2-row*0.3,0.13),Color("839461"),Vector3(0,0,0.5))
			if motif==1 and ambient.targets.size()<2: _moving(ambient,"leaf",bake.frame.origin+Vector3(0,1.7,0.13),record.phase)
		elif motif == 0:
			# Pipe arch, collars and valve. All thin decorations above foot level.
			for side in [-1,1]:
				bake.pipe(Vector3(side*0.6,0.65,0.03), Vector3(side*0.6,2.45,0.03), 0.1, COPPER)
				for height in [0.8,1.5,2.25]: bake.pipe(Vector3(side*0.6,height-0.045,0.03), Vector3(side*0.6,height+0.045,0.03),0.145,BRASS)
			bake.pipe(Vector3(-0.6,2.45,0.03),Vector3(0.6,2.45,0.03),0.1,COPPER)
			if ambient.targets.size()<2: _moving(ambient,"valve",bake.frame.origin+Vector3(0,1.4,0.13),record.phase)
			else: _wheel(bake,Vector3(0,1.4,0.13))
		elif motif==1:
			var points := PackedVector2Array([Vector2(-0.47,0.6),Vector2(0,0.35),Vector2(0.47,0.6),Vector2(0.47,2.3),Vector2(-0.47,2.3)])
			bake.cutout(points,0.06,Transform3D(Basis.IDENTITY,Vector3.ZERO),Color("366c79") if posmod(seed_value+index,3) else Color("935748"),BRASS)
			bake.pipe(Vector3(-0.6,2.35,0),Vector3(0.6,2.35,0),0.055,BRASS)
			var corners := [Vector3(0,1.15,0.06),Vector3(0.22,1.5,0.06),Vector3(0,1.85,0.06),Vector3(-0.22,1.5,0.06)]
			for edge in 4: bake.beam(corners[edge],corners[(edge+1)%4],0.045,BRASS)
		else:
			bake.box(Vector3(1.1,1.4,0.18),Vector3(0,1.25,0),Color("526873"))
			bake.box(Vector3(1.16,0.12,0.2),Vector3(0,2.0,0),BRASS)
			for side in [-1,1]: bake.pipe(Vector3(side*0.63,0.6,0),Vector3(side*0.63,2.25,0),0.075,COPPER)
			for segment in 12:
				var a := segment*TAU/12
				var b := (segment+1)*TAU/12
				bake.pipe(Vector3(cos(a)*0.23,1.4+sin(a)*0.23,0.13),Vector3(cos(b)*0.23,1.4+sin(b)*0.23,0.13),0.025,BRASS)
			bake.beam(Vector3(0,1.4,0.14),Vector3(0.12,1.56,0.14),0.025,BRASS)
	var result: MeshInstance3D
	if bake.vertex_count>0: result=bake.finish(parent,"DungeonLandmarks")
	else:
		result=MeshInstance3D.new()
		result.name="DungeonLandmarks"
		parent.add_child(result)
	result.set_meta("landmark_count",count)
	result.set_meta("decor_plan",records)
	if not ambient.targets.is_empty(): result.add_child(ambient)
	else: ambient.free()
	if imported.get_child_count()>0: result.add_child(imported)
	else: imported.free()
	if biome=="overgrown_rail": Imported.rail_pair(result,walkable)
	return result

static func _wheel(bake: RefCounted,center: Vector3) -> void:
	for segment in 12:
		var a := segment*TAU/12
		var b := (segment+1)*TAU/12
		bake.pipe(center+Vector3(cos(a)*0.36,sin(a)*0.36,0),center+Vector3(cos(b)*0.36,sin(b)*0.36,0),0.035,BRASS)
	for spoke in 3:
		var angle := spoke*TAU/3
		bake.pipe(center,center+Vector3(cos(angle)*0.34,sin(angle)*0.34,0),0.025,BRASS)

static func _moving(ambient: Node3D,kind: String,position_value: Vector3,phase: float) -> void:
	if (valve_mesh if kind=="valve" else leaf_mesh)==null:
		var bake := Bake.new()
		if kind=="valve": _wheel(bake,Vector3.ZERO)
		else:
			for vine in 3:
				for row in 3: bake.box(Vector3(0.2,0.12,0.025),Vector3(-0.5+vine*0.42,0.5-row*0.3,0),Color("839461"),Vector3(0,0,0.5))
		var holder := Node3D.new()
		var part := bake.finish(holder,"CachedAmbient")
		if kind=="valve": valve_mesh=part.mesh
		else: leaf_mesh=part.mesh
		if moving_material==null: moving_material=part.material_override
		holder.free()
	var part := MeshInstance3D.new()
	part.name="AmbientValve" if kind=="valve" else "AmbientLeaves"
	part.mesh=valve_mesh if kind=="valve" else leaf_mesh
	part.material_override=moving_material
	part.position=position_value
	ambient.add_child(part)
	ambient.add_target(part,kind,phase)
