extends MultiMeshInstance3D
## Sparse, non-solid meadow grass. Hidden beneath placed parts on grid changes.
var cells: Array[Vector2i] = []
var transforms: Array[Transform3D] = []

func _ready() -> void:
	name = "MeadowDressing"
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in 5:
		var x := (index - 2) * 0.16
		surface.set_color(Color("668546"))
		for point in [Vector3(x - 0.05, 0, 0), Vector3(x + 0.09, 0.18 + (index % 3) * 0.07, 0.06), Vector3(x + 0.08, 0, 0.1)]:
			surface.add_vertex(point)
	# Sparse tiny paper petals share the grass draw call and coverage mask.
	for offset in [-0.24, 0.3]:
		surface.set_color(Color("e0c780"))
		for point in [Vector3(offset-0.065,0.17,0.02),Vector3(offset,0.26,0.045),Vector3(offset+0.065,0.17,0.02)]:
			surface.add_vertex(point)
	surface.generate_normals()
	var material := StandardMaterial3D.new()
	material.albedo_color = Color.WHITE
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = 1.0
	surface.set_material(material)
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.mesh = surface.commit()
	for z in range(1, 64, 3):
		for x in range(1, 64, 3):
			if x >= 24 and x <= 26:
				continue
			var key := posmod(x * 71 + z * 31, 97)
			var cell := Vector2i(x, z)
			cells.append(cell)
			transforms.append(Transform3D(Basis(Vector3.UP, key * 0.31), Vector3(x * 2 + (key % 5 - 2) * 0.12, 0.01, z * 2)))
	batch.instance_count = cells.size()
	for index in cells.size():
		batch.set_instance_transform(index, transforms[index])
	multimesh = batch
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func cover(grid: RefCounted) -> void:
	var visible := placement_transforms(grid)
	for index in visible.size():
		multimesh.set_instance_transform(index, visible[index])

func placement_transforms(grid: RefCounted) -> Array[Transform3D]:
	var visible: Array[Transform3D] = []
	var occupied: Dictionary = {}
	for id: String in grid.state.town_objects:
		var record: Dictionary = grid.state.town_objects[id]
		if record.placed:
			for cell: Vector2i in grid.cells(record.piece_id, record.cell, record.rotation):
				occupied[cell] = true
	for index in cells.size():
		var transform := transforms[index]
		if occupied.has(cells[index]):
			transform.basis = Basis(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO)
		visible.append(transform)
	return visible
