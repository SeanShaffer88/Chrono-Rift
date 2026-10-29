extends RefCounted
## Two closed opaque prongs; restrained material emission, no added light/effects.
const Bake = preload("res://scripts/utilities/art_mesh.gd")
static var _meshes: Dictionary = {}
static var _materials: Dictionary = {}

static func _material(energy: bool) -> StandardMaterial3D:
	if not _materials.has(energy):
		var value := StandardMaterial3D.new()
		value.vertex_color_use_as_albedo=true
		value.roughness=0.9
		if energy:
			value.emission_enabled=true
			value.emission=Color("db263c")
			value.emission_energy_multiplier=0.65
		_materials[energy]=value
	return _materials[energy]

static func _shape(kind: String) -> Mesh:
	if _meshes.has(kind): return _meshes[kind]
	var bake := Bake.new()
	if kind == "grip":
		bake.box(Vector3(0.42,0.12,0.16),Vector3(0,0,0.15),Color("42484b"))
		bake.pipe(Vector3(0,0,0.2),Vector3(0,0,0.45),0.065,Color("262e35"))
		bake.box(Vector3(0.16,0.10,0.09),Vector3(0,0,0.47),Color("727b79"))
		for side in [-1,1]: bake.box(Vector3(0.10,0.14,0.17),Vector3(side*0.18,0,0.07),Color("8d504c"))
	else:
		for side in [-1,1]:
			var points := PackedVector2Array()
			var profile := [Vector2(0.08,0.12),Vector2(0.27,0.10),Vector2(0.43,-0.48),Vector2(0.34,-0.98),Vector2(0.18,-0.72),Vector2(0.14,-0.26)] if kind == "prongs" else [Vector2(0.15,0.04),Vector2(0.21,0.03),Vector2(0.33,-0.48),Vector2(0.29,-0.80),Vector2(0.22,-0.61),Vector2(0.18,-0.22)]
			for point: Vector2 in profile: points.append(Vector2(point.x*side,point.y))
			if Geometry2D.is_polygon_clockwise(points): points.reverse()
			if kind == "prongs":
				bake.cutout(points,0.07,Transform3D(Basis(Vector3.RIGHT,PI/2),Vector3.ZERO),Color("d62b43"),Color("7b263b"))
			else:
				for face in [-1,1]:
					bake.cutout(points,0.008,Transform3D(Basis(Vector3.RIGHT,PI/2),Vector3(0,face*0.044,0)),Color("ffd0c8"),Color("f05d69"))
	var holder := Node3D.new()
	_meshes[kind]=bake.finish(holder,"EnergySwordMesh").mesh
	holder.free()
	return _meshes[kind]

static func make() -> Node3D:
	var root := Node3D.new()
	root.name="ChainBlade" # Compatibility path for the existing rift_chain weapon owner.
	for kind in ["grip","prongs","inner"]:
		var part := MeshInstance3D.new()
		part.name="Grip" if kind == "grip" else "ForkedProngs" if kind == "prongs" else "HotInnerEdges"
		part.mesh=_shape(kind)
		part.material_override=_material(kind != "grip")
		root.add_child(part)
	return root
