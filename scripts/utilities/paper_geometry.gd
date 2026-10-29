extends RefCounted
## Bounded shared folded-card meshes, built on first use; no per-frame baking.
const Bake = preload("res://scripts/utilities/art_mesh.gd")
static var _meshes: Dictionary = {}
static var _materials: Dictionary = {}

static func material(color: Color) -> StandardMaterial3D:
	if not _materials.has(color):
		var value := StandardMaterial3D.new()
		value.albedo_color=color
		value.vertex_color_use_as_albedo=true
		value.roughness=1.0
		_materials[color]=value
	return _materials[color]

static func shape(kind: String) -> Mesh:
	var key := kind if kind in ["head","hair","torso","taper"] else "panel"
	if _meshes.has(key): return _meshes[key]
	var points := PackedVector2Array([Vector2(-0.42,-0.5),Vector2(0.42,-0.5),Vector2(0.5,0.25),Vector2(0.3,0.5),Vector2(-0.3,0.5),Vector2(-0.5,0.25)])
	if key == "torso": points=PackedVector2Array([Vector2(-0.5,-0.5),Vector2(0.5,-0.5),Vector2(0.38,0.5),Vector2(-0.38,0.5)])
	elif key == "head": points=PackedVector2Array([Vector2(-0.36,-0.42),Vector2(0,-0.5),Vector2(0.36,-0.42),Vector2(0.5,0.1),Vector2(0.38,0.5),Vector2(-0.38,0.5),Vector2(-0.5,0.1)])
	elif key == "hair" or key == "taper": points=PackedVector2Array([Vector2(-0.5,-0.4),Vector2(0.45,-0.5),Vector2(0.5,0.2),Vector2(0.05,0.5),Vector2(-0.42,0.3)])
	var bake := Bake.new()
	# A closed folded volume, sandwiched between thin, offset card layers.
	bake.cutout(points,0.80,Transform3D.IDENTITY,Color("d9d4c6"),Color("f2e5cb"))
	for side in [-1,1]:
		var frame := Transform3D(Basis.IDENTITY.scaled(Vector3(0.94,0.94,1)),Vector3(0,0.015,side*0.43))
		bake.cutout(points,0.045,frame,Color.WHITE,Color("f3ead6"))
		# Raised folded seam has real depth on both faces.
		bake.beam(Vector3(-0.21,-0.36,side*0.47),Vector3(-0.13,0.36,side*0.47),0.018,Color("e8dfcc"))
	var holder := Node3D.new()
	_meshes[key]=bake.finish(holder,"FoldedCard").mesh
	holder.free()
	return _meshes[key]
