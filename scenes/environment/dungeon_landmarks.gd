extends RefCounted
const Imported = preload("res://scenes/environment/imported_landmarks.gd")
const Bake = preload("res://scripts/utilities/art_mesh.gd")
const COPPER := Color("926346")
const BRASS := Color("c1a66c")

static func build(parent: Node3D, rooms: Array[Rect2i], walkable: Dictionary, seed_value: int,biome: String = "foundry") -> Node3D:
	var bake := Bake.new()
	var count := 0
	var frost_details := 0
	var imported := Node3D.new()
	imported.name="ImportedFrostDetails"
	for index in mini(8, rooms.size()):
		var room := rooms[index]
		var anchor := Vector2i(-1,-1)
		for offset in range(1, room.size.x-1):
			var cell := room.position + Vector2i(offset,0)
			if not walkable.has(cell + Vector2i.UP) and (biome!="frost" or posmod(cell.x,3)!=0):
				anchor = cell
				break
		if anchor.x < 0: continue
		count += 1
		bake.frame = Transform3D(Basis.IDENTITY, Vector3(anchor.x*2,0,anchor.y*2-1.08))
		if biome == "frost":
			var replaced := false
			if frost_details<2:
				replaced=Imported.frost_detail(imported,bake.frame.origin,"valve" if frost_details==0 else "piston")
				frost_details+=1
			# Buried heater/cabinet and frosted pipe loop, fixed to the wall.
			bake.box(Vector3(1.25,1.15,0.18),Vector3(0,0.7,0),Color("719ca4"))
			bake.box(Vector3(1.3,0.12,0.22),Vector3(0,1.32,0),Color("e3e7d9"))
			for side in [-1,1]:
				bake.pipe(Vector3(side*0.72,0.4,0.03),Vector3(side*0.72,2.4,0.03),0.09,Color("cbded8"))
				if not replaced: bake.box(Vector3(0.12,0.45,0.04),Vector3(side*0.25,0.82,0.12),Color("d8a252"))
			bake.box(Vector3(0.65,0.22,0.22),Vector3(0,0.15,0.05),Color("dce4da"))
		elif biome == "overgrown_rail":
			# Station panel, rusted engine housing and paper vines, inside solid edge.
			bake.box(Vector3(1.3,0.85,0.18),Vector3(0,0.55,0),Color("795d47"))
			for wheel in [-0.43,0.43]: bake.pipe(Vector3(wheel,0.3,-0.04),Vector3(wheel,0.3,0.18),0.22,Color("424b43"))
			bake.box(Vector3(0.8,0.26,0.14),Vector3(0,1.95,0),Color("c4c6a6"))
			for vine in 3:
				bake.beam(Vector3(-0.5+vine*0.42,2.4,0.1),Vector3(-0.4+vine*0.36,1.15,0.1),0.045,Color("6c8656"))
				for row in 3: bake.box(Vector3(0.2,0.12,0.025),Vector3(-0.5+vine*0.42,2.2-row*0.3,0.13),Color("839461"),Vector3(0,0,0.5))
		elif index % 2 == 0:
			# Pipe arch, collars and valve. All thin decorations above foot level.
			for side in [-1,1]:
				bake.pipe(Vector3(side*0.6,0.65,0.03), Vector3(side*0.6,2.45,0.03), 0.1, COPPER)
				for height in [0.8,1.5,2.25]: bake.pipe(Vector3(side*0.6,height-0.045,0.03), Vector3(side*0.6,height+0.045,0.03),0.145,BRASS)
			bake.pipe(Vector3(-0.6,2.45,0.03),Vector3(0.6,2.45,0.03),0.1,COPPER)
			for segment in 12:
				var a := segment*TAU/12
				var b := (segment+1)*TAU/12
				bake.pipe(Vector3(cos(a)*0.36,1.4+sin(a)*0.36,0.13),Vector3(cos(b)*0.36,1.4+sin(b)*0.36,0.13),0.035,BRASS)
			for spoke in 3:
				var angle := spoke*TAU/3
				bake.pipe(Vector3(0,1.4,0.13), Vector3(cos(angle)*0.34,1.4+sin(angle)*0.34,0.13),0.025,BRASS)
		else:
			var points := PackedVector2Array([Vector2(-0.47,0.6),Vector2(0,0.35),Vector2(0.47,0.6),Vector2(0.47,2.3),Vector2(-0.47,2.3)])
			bake.cutout(points,0.06,Transform3D(Basis.IDENTITY,Vector3.ZERO),Color("366c79") if posmod(seed_value+index,3) else Color("935748"),BRASS)
			bake.pipe(Vector3(-0.6,2.35,0),Vector3(0.6,2.35,0),0.055,BRASS)
			var corners := [Vector3(0,1.15,0.06),Vector3(0.22,1.5,0.06),Vector3(0,1.85,0.06),Vector3(-0.22,1.5,0.06)]
			for edge in 4: bake.beam(corners[edge],corners[(edge+1)%4],0.045,BRASS)
	var result := bake.finish(parent,"DungeonLandmarks")
	result.set_meta("landmark_count",count)
	if imported.get_child_count()>0: result.add_child(imported)
	else: imported.free()
	if biome=="overgrown_rail": Imported.rail_pair(result,walkable)
	return result
