extends RefCounted
## Town-only opaque materials and thick cutout foliage. No gameplay collision.
const Factory = preload("res://scripts/utilities/primitive_mesh_factory.gd")
const SHADER = preload("res://assets/shaders/paper_surface.gdshader")
const Assets = preload("res://scripts/utilities/environment_assets.gd")
const Bake = preload("res://scripts/utilities/art_mesh.gd")

static func material(color: Color, texture: Texture2D = null, vertex_colors: bool = false, roof: bool = false) -> ShaderMaterial:
	var result := ShaderMaterial.new()
	result.shader = SHADER
	result.set_shader_parameter("tint", color)
	if texture != null:
		result.set_shader_parameter("palette_texture", texture)
	result.set_shader_parameter("vertex_colors", float(vertex_colors))
	result.set_shader_parameter("red_roof", float(roof))
	return result

static func apply(root: Node) -> void:
	# Cache within this model; never mutate imported/shared materials.
	var cache: Dictionary = {}
	for node: Node in root.find_children("*", "MeshInstance3D", true, false):
		if node.material_override is StandardMaterial3D:
			var original: StandardMaterial3D = node.material_override
			if not cache.has(original):
				cache[original] = material(original.albedo_color, original.albedo_texture, original.vertex_color_use_as_albedo)
			node.material_override = cache[original]
			continue
		for index in node.mesh.get_surface_count():
			var original: Material = node.get_active_material(index)
			if original is StandardMaterial3D:
				if not cache.has(original):
					cache[original] = material(original.albedo_color, original.albedo_texture, original.vertex_color_use_as_albedo)
				node.set_surface_override_material(index, cache[original])

static func tree(parent: Node3D, at: Vector3, factor: float = 1.0, shaded: bool = true) -> Node3D:
	var root := Node3D.new()
	root.name = "PaperTree"
	root.position = at
	root.scale = Vector3.ONE * factor
	parent.add_child(root)
	var trunk := Factory.create_box(Vector3(0.22, 2.7, 0.16), Color("77523a"))
	trunk.position.y = 1.35
	root.add_child(trunk)
	# Two thick, folded silhouettes remain readable while freely orbiting.
	for side in 2:
		var card := Node3D.new()
		card.rotation.y = side * PI / 2
		root.add_child(card)
		for layer in 3:
			var width := 1.1 - layer * 0.22
			var y := 0.9 + layer * 0.65
			var surface := SurfaceTool.new()
			surface.begin(Mesh.PRIMITIVE_TRIANGLES)
			var points := [Vector2(-width, y), Vector2(width, y), Vector2(0, y + 1.5)]
			for depth in [-0.065, 0.065]:
				for index in ([0, 1, 2] if depth < 0 else [2, 1, 0]):
					surface.add_vertex(Vector3(points[index].x, points[index].y, depth))
			surface.generate_normals()
			var leaf := MeshInstance3D.new()
			leaf.mesh = surface.commit()
			leaf.material_override = Factory.get_shared_material(Color("4c8053").lightened(layer * 0.045))
			card.add_child(leaf)
			var edges := SurfaceTool.new()
			edges.begin(Mesh.PRIMITIVE_TRIANGLES)
			for index in 3:
				var a: Vector2 = points[index]
				var b: Vector2 = points[(index + 1) % 3]
				for point in [Vector3(a.x,a.y,-0.065), Vector3(a.x,a.y,0.065), Vector3(b.x,b.y,-0.065), Vector3(b.x,b.y,-0.065), Vector3(a.x,a.y,0.065), Vector3(b.x,b.y,0.065)]:
					edges.add_vertex(point)
			edges.generate_normals()
			var edge := MeshInstance3D.new()
			edge.mesh = edges.commit()
			edge.material_override = Factory.get_shared_material(Color("dfce9a"))
			card.add_child(edge)
	# Bake cards, edge colors and trunk into one draw surface per tree.
	var combined := SurfaceTool.new()
	combined.begin(Mesh.PRIMITIVE_TRIANGLES)
	for entry: Dictionary in Assets.meshes(root):
		var transform := root.transform.affine_inverse() * (entry.transform as Transform3D)
		var source: Material = entry.node.material_override
		var color: Color = source.albedo_color if source is StandardMaterial3D else source.get_shader_parameter("tint")
		combined.set_color(color)
		for point: Vector3 in entry.node.mesh.get_faces():
			combined.add_vertex(transform * point)
	combined.generate_normals()
	for child: Node in root.get_children():
		child.free()
	var mesh := MeshInstance3D.new()
	mesh.mesh = combined.commit()
	var fallback := StandardMaterial3D.new()
	fallback.vertex_color_use_as_albedo = true
	mesh.material_override = material(Color.WHITE, null, true) if shaded else fallback
	root.add_child(mesh)
	return root

static func round_tree(parent: Node3D, at: Vector3, factor: float = 1.0, shaded: bool = true) -> Node3D:
	var root := Node3D.new()
	root.name = "RoundPaperTree"
	root.position = at
	root.scale = Vector3.ONE * factor
	parent.add_child(root)
	var bake := Bake.new()
	bake.box(Vector3(0.24, 2.3, 0.18), Vector3(0, 1.15, 0), Color("79553c"))
	for side in [-1, 1]:
		bake.beam(Vector3(0,1.5,0), Vector3(side*0.6,2.2,0), 0.12, Color("79553c"))
	for layer in 3:
		var points := PackedVector2Array()
		for index in 10:
			var angle := index * TAU / 10
			var radius := 1.05 + sin(index * 2.4 + layer) * 0.13
			points.append(Vector2(cos(angle)*radius, sin(angle)*radius + 2.35))
		var rotation := Basis(Vector3.UP, layer * PI / 3)
		bake.cutout(points, 0.13, Transform3D(rotation, Vector3(0,layer*0.08,0)), Color("6f944e").lightened(layer*0.06), Color("e5d4a3"))
	bake.finish(root, "FoldedCanopy", material(Color.WHITE, null, true) if shaded else null)
	return root
