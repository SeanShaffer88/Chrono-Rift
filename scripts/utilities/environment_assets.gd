extends RefCounted
## Selected authored geometry, normalized without changing gameplay collision.
const MODELS = {
	"wall": preload("res://assets/kenney/dungeon/template-wall.glb"),
	"wall_detail": preload("res://assets/kenney/dungeon/template-wall-detail-a.glb"),
	"floor": preload("res://assets/kenney/dungeon/template-floor-detail.glb"),
	"floor_alt": preload("res://assets/kenney/dungeon/template-floor-detail-a.glb"),
	"pier": preload("res://assets/kenney/dungeon/template-detail.glb"),
	"wood_wall": preload("res://assets/kenney/town-detail/wall-wood.glb"),
	"window_wall": preload("res://assets/kenney/town-detail/wall-wood-window-shutters.glb"),
	"roof": preload("res://assets/kenney/town-detail/roof-gable.glb"),
	"chimney": preload("res://assets/kenney/town-detail/chimney.glb"),
	"wheel": preload("res://assets/kenney/town-detail/wheel.glb"),
}

static func meshes(node: Node3D, transform: Transform3D = Transform3D.IDENTITY) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var local := transform * node.transform
	if node is MeshInstance3D and node.mesh != null:
		result.append({"node": node, "transform": local})
	for child: Node in node.get_children():
		if child is Node3D:
			result.append_array(meshes(child, local))
	return result

static func bounds(node: Node3D) -> AABB:
	var result := AABB()
	var first := true
	for entry: Dictionary in meshes(node):
		var box: AABB = entry.transform * entry.node.mesh.get_aabb()
		result = box if first else result.merge(box)
		first = false
	return result

static func fit(kind: String, size: Vector3, at: Vector3, orientation: float = 0.0) -> Node3D:
	var wrapper := Node3D.new()
	var container := Node3D.new()
	var model: Node3D = MODELS[kind].instantiate()
	# Town wall models run along Z with the front normal on +X.
	if kind in ["wood_wall", "window_wall"]:
		model.rotation.y = PI / 2
	var box := bounds(model)
	model.position -= Vector3(box.get_center().x, box.position.y, box.get_center().z)
	container.scale = size / box.size.max(Vector3.ONE * 0.001)
	container.add_child(model)
	wrapper.add_child(container)
	wrapper.position = at
	wrapper.rotation.y = orientation
	return wrapper

static func batch(kind: String, transforms: Array[Transform3D], colors: Array[Color] = []) -> Node3D:
	var root := Node3D.new()
	root.name = kind.to_pascal_case() + "Batch"
	var source: Node3D = MODELS[kind].instantiate()
	for entry: Dictionary in meshes(source):
		var mesh: Mesh = entry.node.mesh.duplicate()
		for surface in mesh.get_surface_count():
			var original := mesh.surface_get_material(surface) as StandardMaterial3D
			if original != null:
				var material := original.duplicate() as StandardMaterial3D
				material.vertex_color_use_as_albedo = true
				# This dungeon archive includes opposite coplanar faces. Back culling
				# prevents them fighting under Compatibility and halves raster work.
				material.cull_mode = BaseMaterial3D.CULL_BACK
				mesh.surface_set_material(surface, material)
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.use_colors = true
		multi.mesh = mesh
		multi.instance_count = transforms.size()
		for index in transforms.size():
			multi.set_instance_transform(index, transforms[index] * entry.transform)
			multi.set_instance_color(index, Color.WHITE if colors.is_empty() else colors[index])
		var instance := MultiMeshInstance3D.new()
		instance.multimesh = multi
		root.add_child(instance)
	source.free()
	return root
