extends RefCounted
## Shared faceted unit meshes. Per-instance scale/color never mutate this cache.
static var _meshes: Dictionary = {}

static func shape(kind: String = "round") -> Mesh:
	if _meshes.has(kind): return _meshes[kind]
	if kind in ["hair", "head"]:
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		surface.set_smooth_group(-1)
		var rings := [Vector2(0.43,-0.5),Vector2(0.53,-0.12),Vector2(0.39,0.32),Vector2(0.0,0.5)] if kind == "hair" else [Vector2(0.30,-0.5),Vector2(0.47,-0.28),Vector2(0.50,0.22),Vector2(0.34,0.5),Vector2(0,0.5)]
		for level in rings.size()-1:
			for sector in 10:
				var points: Array[Vector3] = []
				for pair: Vector2i in [Vector2i(level,sector),Vector2i(level,sector+1),Vector2i(level+1,sector),Vector2i(level+1,sector+1)]:
					var angle := pair.y*TAU/10
					var ring: Vector2 = rings[pair.x]
					var sweep := ring.y*0.24 if kind == "hair" else 0.0
					points.append(Vector3(cos(angle)*ring.x+sweep,ring.y,sin(angle)*ring.x))
				# Godot front faces are clockwise; skip the collapsed apex triangle.
				for triangle in [[0,1,2],[1,3,2]]:
					if (points[triangle[1]]-points[triangle[0]]).cross(points[triangle[2]]-points[triangle[0]]).length_squared() > 0.00000001:
						for index in triangle: surface.add_vertex(points[index])
		# Close the underside with clockwise downward-facing triangles.
		for sector in 10:
			var ring: Vector2 = rings[0]
			var sweep := ring.y*0.24 if kind == "hair" else 0.0
			var a := sector*TAU/10
			var b := (sector+1)*TAU/10
			for point in [Vector3(sweep,ring.y,0),Vector3(cos(b)*ring.x+sweep,ring.y,sin(b)*ring.x),Vector3(cos(a)*ring.x+sweep,ring.y,sin(a)*ring.x)]: surface.add_vertex(point)
		surface.generate_normals()
		_meshes[kind] = surface.commit()
		return _meshes[kind]
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
