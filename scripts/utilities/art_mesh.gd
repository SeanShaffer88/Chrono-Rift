extends RefCounted
## Bake static colored primitives into one opaque surface, preserving no collision.
var surface := SurfaceTool.new()
var vertex_count := 0
var frame := Transform3D.IDENTITY

func _init() -> void:
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_smooth_group(-1)

func mesh(source: Mesh, transform: Transform3D, color: Color) -> void:
	surface.set_color(color)
	for point: Vector3 in source.get_faces():
		surface.add_vertex(frame * transform * point)
		vertex_count += 1

func box(size: Vector3, at: Vector3, color: Color, rotation: Vector3 = Vector3.ZERO) -> void:
	var shape := BoxMesh.new()
	shape.size = size
	mesh(shape, Transform3D(Basis.from_euler(rotation), at), color)

func beam(start: Vector3, end: Vector3, width: float, color: Color) -> void:
	var delta := end - start
	var shape := BoxMesh.new()
	shape.size = Vector3(width, delta.length(), width)
	var basis := Basis(Quaternion(Vector3.UP, delta.normalized()))
	mesh(shape, Transform3D(basis, (start + end) / 2), color)

func pipe(start: Vector3, end: Vector3, radius: float, color: Color) -> void:
	var delta := end - start
	var shape := CylinderMesh.new()
	shape.top_radius = radius
	shape.bottom_radius = radius
	shape.height = delta.length()
	shape.radial_segments = 8
	mesh(shape, Transform3D(Basis(Quaternion(Vector3.UP, delta.normalized())), (start + end) / 2), color)

func cutout(points: PackedVector2Array, depth: float, transform: Transform3D, color: Color, edge: Color) -> void:
	var indices := Geometry2D.triangulate_polygon(points)
	for side in [-1, 1]:
		surface.set_color(color)
		for triangle in range(0, indices.size(), 3):
			for offset in ([0, 1, 2] if side == -1 else [2, 1, 0]):
				var point := points[indices[triangle + offset]]
				surface.add_vertex(frame * transform * Vector3(point.x, point.y, side * depth / 2))
				vertex_count += 1
	surface.set_color(edge)
	for index in points.size():
		var a := points[index]
		var b := points[(index + 1) % points.size()]
		for point in [Vector3(a.x,a.y,-depth/2), Vector3(a.x,a.y,depth/2), Vector3(b.x,b.y,-depth/2), Vector3(b.x,b.y,-depth/2), Vector3(a.x,a.y,depth/2), Vector3(b.x,b.y,depth/2)]:
			surface.add_vertex(frame * transform * point)
			vertex_count += 1

func finish(parent: Node3D, name_value: String, material: Material = null) -> MeshInstance3D:
	var result := MeshInstance3D.new()
	result.name = name_value
	surface.generate_normals()
	result.mesh = surface.commit()
	if material == null:
		var colored := StandardMaterial3D.new()
		colored.vertex_color_use_as_albedo = true
		colored.roughness = 0.95
		result.material_override = colored
	else:
		result.material_override = material
	parent.add_child(result)
	return result
