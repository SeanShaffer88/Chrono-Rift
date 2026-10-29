extends RefCounted
const Bake = preload("res://scripts/utilities/art_mesh.gd")
static var _meshes: Dictionary = {}
static var _material: StandardMaterial3D

static func material() -> StandardMaterial3D:
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.vertex_color_use_as_albedo = true
		_material.metallic = 0.25
		_material.roughness = 0.5
	return _material

static func mesh(id: String) -> Mesh:
	if _meshes.has(id): return _meshes[id]
	var bake := Bake.new()
	var steel := Color("aab7be")
	if id == "battle_wrench":
		bake.pipe(Vector3(0,0,-0.46),Vector3(0,0,0.44),0.075,steel)
		bake.pipe(Vector3(0,0,0.08),Vector3(0,0,0.4),0.086,Color("71533c"))
	else:
		var tip := -0.8 if id == "duskblade" else -0.65
		var points := PackedVector2Array([Vector2(-0.07,0.18),Vector2(0.07,0.18),Vector2(0.07,tip+0.2),Vector2(0,tip),Vector2(-0.07,tip+0.2)])
		bake.cutout(points,0.045,Transform3D(Basis(Vector3.RIGHT,PI/2),Vector3.ZERO),steel,Color("d9e1e0"))
		bake.box(Vector3(0.36,0.075,0.09),Vector3(0,0,0.2),Color("a69d83"))
		bake.pipe(Vector3(0,0,0.24),Vector3(0,0,0.46),0.055,Color("574359"))
		bake.box(Vector3(0.1,0.085,0.07),Vector3(0,0,0.48),steel)
	var holder := Node3D.new()
	var instance := bake.finish(holder,"Weapon",material())
	_meshes[id] = instance.mesh
	holder.free()
	return _meshes[id]
