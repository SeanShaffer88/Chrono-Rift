extends RefCounted
## Shared faceted unit meshes. Per-instance scale/color never mutate this cache.
static var _meshes: Dictionary = {}

static func shape(kind: String = "round") -> Mesh:
	if _meshes.has(kind): return _meshes[kind]
	var source: PrimitiveMesh
	if kind in ["torso","taper"]:
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = 0.0 if kind == "taper" else 0.5
		cylinder.bottom_radius = 0.5 if kind == "taper" else 0.42
		cylinder.height = 1.0
		cylinder.radial_segments = 8
		source = cylinder
	else:
		var sphere := SphereMesh.new()
		sphere.radius = 0.5
		sphere.height = 1.0
		sphere.radial_segments = 10
		sphere.rings = 5
		source = sphere
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_smooth_group(-1)
	for vertex: Vector3 in source.get_faces(): surface.add_vertex(vertex)
	surface.generate_normals()
	_meshes[kind] = surface.commit()
	return _meshes[kind]
