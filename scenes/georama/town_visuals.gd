extends RefCounted
## Original primitive architecture. Shells, doors and furniture are physical.

const Scenery = preload("res://scripts/utilities/scenery.gd")
const Factory := preload("res://scripts/utilities/primitive_mesh_factory.gd")

static func box(parent: Node3D, size: Vector3, position: Vector3, color: Color, solid: bool = false) -> MeshInstance3D:
	var mesh := Factory.create_box(size, color)
	mesh.position = position
	parent.add_child(mesh)
	if solid:
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		var shape := BoxShape3D.new()
		shape.size = size
		var collision := CollisionShape3D.new()
		collision.shape = shape
		collision.position = position
		body.add_child(collision)
		parent.add_child(body)
	return mesh

static func make(piece: Resource, record: Dictionary, preview: bool = false) -> Node3D:
	var root := Node3D.new()
	var width: float = piece.dimensions.x * 2.0
	var depth: float = piece.dimensions.y * 2.0
	var components: Dictionary = record.components
	if piece.piece_id in ["path", "bridge", "river"]:
		box(root, Vector3(width, 0.05, depth), Vector3.ZERO, Color(0.1, 0.45, 0.65) if piece.piece_id == "river" else Color(0.4, 0.31, 0.2))
		if piece.piece_id == "bridge":
			for side in [-1, 1]:
				box(root, Vector3(0.12, 0.12, depth), Vector3(side * (width / 2 - 0.15), 0.75, 0), Color("785334"))
				for end in [-1, 1]:
					box(root, Vector3(0.18, 1.0, 0.18), Vector3(side * (width / 2 - 0.15), 0.5, end * (depth / 2 - 0.15)), Color("67452e"))
			for plank in int(depth / 0.4):
				box(root, Vector3(width, 0.08, 0.34), Vector3(0, 0.06, -depth / 2 + 0.2 + plank * 0.4), Color("aa7d4c"))
	elif piece.piece_id == "tree":
		box(root, Vector3(0.5, 2.5, 0.5), Vector3(0, 1.25, 0), Color(0.3, 0.2, 0.12), not preview)
		Scenery.add(root, "tree", Vector3.ZERO, 1.8)
	else:
		var stone := Color("e1c89b")
		var timber := Color("62432f")
		for x in [-width / 2 + 0.08, width / 2 - 0.08]:
			for z in [-depth / 2 + 0.08, depth / 2 - 0.08]:
				box(root, Vector3(0.28, 2.6, 0.28), Vector3(x, 1.3, z), timber)
		for z in [-depth / 2 - 0.02, depth / 2 + 0.02]:
			box(root, Vector3(width, 0.2, 0.24), Vector3(0, 2.52, z), timber)
		# Shutters flank the entrance, outside its walkable opening.
		for side in [-1, 1]:
			box(root, Vector3(0.8, 0.85, 0.15), Vector3(side * width * 0.31, 1.55, -depth / 2 - 0.09), Color("406479"))
		box(root, Vector3(width - 0.2, 0.04, depth - 0.2), Vector3(0, 0.02, 0), Color(0.4, 0.29, 0.18))
		box(root, Vector3(0.2, 2.5, depth), Vector3(-width / 2 + 0.1, 1.25, 0), stone, not preview)
		box(root, Vector3(0.2, 2.5, depth), Vector3(width / 2 - 0.1, 1.25, 0), stone, not preview)
		box(root, Vector3(width, 2.5, 0.2), Vector3(0, 1.25, depth / 2 - 0.1), stone, not preview)
		var segment := (width - 1.5) / 2
		for side in [-1, 1]:
			box(root, Vector3(segment, 2.5, 0.2), Vector3(side * (0.75 + segment / 2), 1.25, -depth / 2 + 0.1), stone, not preview)
		if components.has("Roof"):
			var roof := MeshInstance3D.new()
			roof.name = "Roof"
			var prism := PrismMesh.new()
			prism.size = Vector3(width + 0.5, 1.6, depth + 0.5)
			roof.mesh = prism
			roof.material_override = Factory.get_shared_material(Color("b84e35"))
			roof.position.y = 3.2
			root.add_child(roof)
			Scenery.add(roof, "lantern", Vector3(width * 0.3, -1.4, -depth / 2 - 0.2), 0.8)
			box(root, Vector3(0.5, 1.5, 0.5), Vector3(width / 3, 3.4, depth / 4), stone)
		if not preview:
			var door := StaticBody3D.new()
			door.name = "Door"
			door.position = Vector3(0, 0, -depth / 2)
			var shape := BoxShape3D.new()
			shape.size = Vector3(1.5, 2.4, 0.2)
			var collision := CollisionShape3D.new()
			collision.name = "Collision"
			collision.position.y = 1.2
			collision.shape = shape
			door.add_child(collision)
			if components.has("Door"):
				var leaf := box(door, Vector3(1.5, 2.4, 0.1), Vector3(0, 1.2, 0), Color(0.28, 0.16, 0.08))
				leaf.name = "Leaf"
			door.set_meta("ready", components.has("Roof") and (components.has("Door") or not piece.slots.has("Door")))
			root.add_child(door)
		if components.has("Bed"):
			box(root, Vector3(1.4, 0.5, 2.0), Vector3(-width / 2 + 1.2, 0.25, 0.6), Color(0.25, 0.35, 0.6), not preview).name = "Bed"
		if components.has("Stove"):
			box(root, Vector3(0.8, 1.0, 0.8), Vector3(width / 2 - 1, 0.5, 0.8), Color(0.25, 0.25, 0.26), not preview).name = "Stove"
		if components.has("Wheel"):
			box(root, Vector3(0.4, 2.0, 2.0), Vector3(width / 2 + 0.25, 1.0, 0), Color(0.32, 0.2, 0.1), not preview)
	return root

static func resident(name: String) -> Node3D:
	var root := Node3D.new()
	var mesh := MeshInstance3D.new()
	var capsule := BoxMesh.new()
	capsule.size = Vector3(0.6, 1.2, 0.4)
	mesh.mesh = capsule
	mesh.material_override = Factory.get_shared_material(Color(0.5, 0.38, 0.22))
	mesh.position.y = 0.8
	root.add_child(mesh)
	box(root, Vector3(0.65, 0.55, 0.55), Vector3(0, 1.65, 0), Color("e6b68a"))
	box(root, Vector3(0.7, 0.16, 0.6), Vector3(0, 1.97, 0), Color("5a3d2e"))
	for side in [-1, 1]:
		box(root, Vector3(0.08, 0.09, 0.03), Vector3(side * 0.17, 1.67, -0.29), Color("283244"))
	var label := Label3D.new()
	label.text = name
	label.position.y = 2.0
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 32
	root.add_child(label)
	return root
