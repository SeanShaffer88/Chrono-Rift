extends RefCounted
const Bake = preload("res://scripts/utilities/art_mesh.gd")
static var _meshes: Dictionary = {}
static var _material: StandardMaterial3D

static func material() -> StandardMaterial3D:
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.vertex_color_use_as_albedo = true
		_material.metallic = 0.0
		_material.roughness = 1.0
	return _material

static func mesh(id: String) -> Mesh:
	if _meshes.has(id): return _meshes[id]
	var bake := Bake.new()
	var steel := Color("aab7be")
	if id == "battle_wrench":
		bake.pipe(Vector3(0,0,-0.46),Vector3(0,0,0.44),0.075,steel)
		bake.pipe(Vector3(0,0,0.08),Vector3(0,0,0.4),0.086,Color("71533c"))
	elif id == "trail_sword":
		var blade_points := PackedVector2Array([Vector2(-0.065,0.17),Vector2(0.065,0.17),Vector2(0.065,-0.48),Vector2(0,-0.66),Vector2(-0.065,-0.48)])
		if Geometry2D.is_polygon_clockwise(blade_points): blade_points.reverse()
		bake.cutout(blade_points,0.045,Transform3D(Basis(Vector3.RIGHT,PI/2),Vector3.ZERO),Color("c4d0d4"),Color("edf0e8"))
		var wing := PackedVector2Array([Vector2(-0.34,0.14),Vector2(-0.23,0.08),Vector2(-0.1,0.15),Vector2(0.1,0.15),Vector2(0.23,0.08),Vector2(0.34,0.14),Vector2(0.16,0.27),Vector2(-0.16,0.27)])
		if Geometry2D.is_polygon_clockwise(wing): wing.reverse()
		bake.cutout(wing,0.075,Transform3D(Basis(Vector3.RIGHT,PI/2),Vector3.ZERO),Color("5d5d9c"),Color("9b9ac4"))
		bake.pipe(Vector3(0,0,0.27),Vector3(0,0,0.46),0.055,Color("454c89"))
		for wrap in 4:
			bake.box(Vector3(0.12,0.105,0.018),Vector3(0,0,0.29+wrap*0.045),Color("7f82b1"))
		bake.box(Vector3(0.12,0.1,0.075),Vector3(0,0,0.49),Color("686da4"))
	elif id == "duskblade":
		# Original broad slab with a flat spine and angular clipped tip.
		var points := PackedVector2Array([Vector2(-0.22,0.17),Vector2(0.22,0.17),Vector2(0.22,-0.74),Vector2(0.03,-1.04),Vector2(-0.22,-1.04)])
		if Geometry2D.is_polygon_clockwise(points): points.reverse()
		bake.cutout(points,0.09,Transform3D(Basis(Vector3.RIGHT,PI/2),Vector3.ZERO),Color("a5b1b5"),Color("e3e6df"))
		for side in [-1,1]:
			bake.box(Vector3(0.028,0.012,0.85),Vector3(-0.17,side*0.055,-0.32),Color("d8dfdc"))
		bake.box(Vector3(0.48,0.11,0.13),Vector3(0,0,0.2),Color("5e625b"))
		bake.pipe(Vector3(0,0,0.24),Vector3(0,0,0.46),0.06,Color("353b3d"))
		bake.box(Vector3(0.12,0.1,0.075),Vector3(0,0,0.48),Color("888f89"))
	else:
		var tip := -0.58 if id == "trail_sword" else -0.8 if id == "duskblade" else -0.65
		var points := PackedVector2Array([Vector2(-0.07,0.18),Vector2(0.07,0.18),Vector2(0.07,tip+0.2),Vector2(0,tip),Vector2(-0.07,tip+0.2)])
		if Geometry2D.is_polygon_clockwise(points): points.reverse()
		bake.cutout(points,0.045,Transform3D(Basis(Vector3.RIGHT,PI/2),Vector3.ZERO),steel,Color("d9e1e0"))
		bake.box(Vector3(0.36,0.075,0.09),Vector3(0,0,0.2),Color("a69d83"))
		bake.pipe(Vector3(0,0,0.24),Vector3(0,0,0.46),0.055,Color("574359"))
		bake.box(Vector3(0.1,0.085,0.07),Vector3(0,0,0.48),steel)
	var holder := Node3D.new()
	var instance := bake.finish(holder,"Weapon",material())
	_meshes[id] = instance.mesh
	holder.free()
	return _meshes[id]
