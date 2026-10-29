extends RefCounted
## Shared immutable materials and text-native primitive geometry.

static var _materials: Dictionary = {}

static func get_shared_material(color: Color, roughness: float = 0.9, emission: float = 0.0) -> StandardMaterial3D:
	var key := "%s|%s|%s" % [color, roughness, emission]
	if not _materials.has(key):
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = roughness
		material.emission_enabled = emission > 0.0
		material.emission = color
		material.emission_energy_multiplier = emission
		_materials[key] = material
	return _materials[key]

static func create_box(size: Vector3, color: Color, emission: float = 0.0) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.material_override = get_shared_material(color, 0.9, emission)
	return instance

static func create_atla_sphere_mesh() -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.35
	mesh.height = 0.7
	mesh.radial_segments = 10
	mesh.rings = 5
	instance.mesh = mesh
	instance.material_override = get_shared_material(Color("59c7cd"), 0.45, 0.35)
	return instance

static func create_tile_batch(cells: Array, size: Vector3, color: Color, cell_size: float, center_y: float) -> MultiMeshInstance3D:
	var instance := MultiMeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.mesh = mesh
	batch.use_colors = true
	batch.instance_count = cells.size()
	for index in cells.size():
		var cell: Vector2i = cells[index]
		var shade := 0.88 + float(posmod(cell.x * 31 + cell.y * 17, 9)) * 0.025
		batch.set_instance_color(index, Color(shade, shade, shade))
		batch.set_instance_transform(index, Transform3D(Basis.IDENTITY, Vector3(cell.x * cell_size, center_y, cell.y * cell_size)))
	instance.multimesh = batch
	var material := get_shared_material(color).duplicate() as StandardMaterial3D
	material.vertex_color_use_as_albedo = true
	instance.material_override = material
	return instance
