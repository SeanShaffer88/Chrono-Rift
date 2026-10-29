extends RefCounted
const Bake = preload("res://scripts/utilities/art_mesh.gd")
const COPPER := Color("926346")
const BRASS := Color("c1a66c")

static func build(parent: Node3D, rooms: Array[Rect2i], walkable: Dictionary, seed_value: int) -> Node3D:
	var bake := Bake.new()
	var count := 0
	for index in mini(8, rooms.size()):
		var room := rooms[index]
		var anchor := Vector2i(-1,-1)
		for offset in range(1, room.size.x-1):
			var cell := room.position + Vector2i(offset,0)
			if not walkable.has(cell + Vector2i.UP):
				anchor = cell
				break
		if anchor.x < 0: continue
		count += 1
		bake.frame = Transform3D(Basis.IDENTITY, Vector3(anchor.x*2,0,anchor.y*2-1.08))
		if index % 2 == 0:
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
	return result
