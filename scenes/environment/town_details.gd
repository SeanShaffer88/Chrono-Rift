extends RefCounted
const Bake = preload("res://scripts/utilities/art_mesh.gd")
const Paper = preload("res://scenes/environment/papercraft.gd")
const CREAM := Color("e0d0a4")
const WOOD := Color("715039")

static func decorate(root: Node3D, width: float, depth: float, components: Dictionary, preview: bool) -> void:
	var material: Material = null if preview else Paper.material(Color.WHITE, null, true)
	var walls := Bake.new()
	var front := -depth / 2 - 0.035
	# Shaped frame and skirting retain the exact open 1.5m doorway.
	for side in [-1, 1]:
		walls.box(Vector3(0.12, 2.55, 0.12), Vector3(side * 0.83, 1.28, front), CREAM)
		walls.box(Vector3((width - 1.9) / 2, 0.18, 0.13), Vector3(side * (width / 4 + 0.47), 0.18, front), Color("b6a27e"))
		# Folded flower boxes stay under the side windows, away from the entrance.
		var x: float = side * (width / 4 + 0.35)
		walls.box(Vector3(0.95, 0.22, 0.32), Vector3(x, 0.88, front - 0.12), WOOD)
		walls.box(Vector3(1.0, 0.045, 0.36), Vector3(x, 1.01, front - 0.12), CREAM)
		for flower in 4:
			var at := Vector3(x - 0.34 + flower * 0.22, 1.1, front - 0.17)
			walls.beam(at - Vector3.UP * 0.1, at + Vector3.UP * 0.15, 0.035, Color("507949"))
			walls.box(Vector3(0.16, 0.04, 0.1), at + Vector3.UP * 0.16, Color("f0d587") if flower % 2 == 0 else Color("ece4c7"), Vector3(0, 0, flower * 0.6))
	walls.box(Vector3(1.8, 0.15, 0.15), Vector3(0, 2.5, front), CREAM)
	walls.finish(root, "PaperHouseDetails", material)
	if components.has("Roof"):
		var roof: Node3D = root.get_node("Roof")
		var gables := Bake.new()
		for side in [-1, 1]:
			var z: float = side * (depth / 2 - 0.03)
			gables.cutout(PackedVector2Array([Vector2(-width/2,0), Vector2(width/2,0), Vector2(0,1.45)]), 0.1, Transform3D(Basis.IDENTITY, Vector3(0,0.12,z)), CREAM, Color("f0e4c1"))
			var face: float = z + side * 0.065
			gables.beam(Vector3(-width/2,0.1,face), Vector3(0,1.59,face), 0.13, WOOD)
			gables.beam(Vector3(width/2,0.1,face), Vector3(0,1.59,face), 0.13, WOOD)
			gables.box(Vector3(0.14,1.35,0.11), Vector3(0,0.8,face), WOOD)
			gables.box(Vector3(1.0,0.4,0.12), Vector3(0,0.47,face + side*0.02), Color("537274"))
			gables.box(Vector3(1.1,0.055,0.15), Vector3(0,0.68,face + side*0.02), WOOD)
		gables.finish(roof, "FoldedGables", material)
		# An awning is part of the recovered roof and hides with it inside.
		var awning := Bake.new()
		awning.box(Vector3(2.05, 0.08, 0.8), Vector3(0,0.03,front-0.3), Color("ae5343"), Vector3(-0.15,0,0))
		awning.box(Vector3(2.1,0.05,0.08), Vector3(0,-0.03,front-0.7), CREAM)
		awning.finish(roof, "FoldedAwning", material)
	if root.has_node("Door/Leaf"):
		var door: Node3D = root.get_node("Door/Leaf")
		var detail := Bake.new()
		for index in 4:
			detail.box(Vector3(0.012,2.2,0.02), Vector3(-0.55 + index*0.36,0,-0.06), Color("ab8656"))
		for y in [-0.72,0.72]: detail.box(Vector3(1.35,0.09,0.045), Vector3(0,y,-0.07), WOOD)
		detail.box(Vector3(0.07,0.17,0.075), Vector3(0.5,-0.1,-0.1), Color("b89957"))
		detail.finish(door, "DoorJoinery", material)
