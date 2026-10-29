extends Node3D
## Original low-poly character art. Collision and combat stay on the parent.
const Factory = preload("res://scripts/utilities/primitive_mesh_factory.gd")
var legs: Array[Node3D] = []
var phase := 0.0
var variant_nodes: Dictionary = {"swordsman": [], "rift_warden": []}

func part(label: String, size: Vector3, at: Vector3, color: Color) -> MeshInstance3D:
	var mesh := Factory.create_box(size, color)
	mesh.name = label
	mesh.position = at
	add_child(mesh)
	return mesh

func _ready() -> void:
	# Preserve inherited node paths for combat and existing scenes.
	$Body.hide()
	$Face.hide()
	var leather := Color("80502e")
	var skin := Color("edb47b")
	part("Tunic", Vector3(0.65, 0.65, 0.4), Vector3(0, 0.95, 0), leather)
	part("Belt", Vector3(0.69, 0.11, 0.44), Vector3(0, 0.7, 0), Color("392c2c"))
	part("Buckle", Vector3(0.16, 0.12, 0.06), Vector3(0, 0.7, -0.25), Color("d6a652"))
	part("Head", Vector3(0.7, 0.62, 0.6), Vector3(0, 1.65, -0.02), skin)
	part("Hair", Vector3(0.78, 0.22, 0.69), Vector3(0, 1.98, 0.02), Color("493026"))
	part("HairBack", Vector3(0.75, 0.42, 0.2), Vector3(0, 1.75, 0.3), Color("493026"))
	for index in 3:
		var tuft := part("HairTuft%d" % index, Vector3(0.26, 0.22, 0.5), Vector3((index - 1) * 0.24, 2.09, 0.04), Color("593729"))
		tuft.rotation.z = (index - 1) * 0.3
	for side in [-1, 1]:
		var fringe := part("Fringe%d" % side, Vector3(0.27, 0.24, 0.16), Vector3(side * 0.23, 1.86, -0.32), Color("593729"))
		fringe.rotation.z = side * 0.2
		part("Eye%d" % side, Vector3(0.07, 0.1, 0.025), Vector3(side * 0.17, 1.65, -0.33), Color("242739"))
		part("Sleeve%d" % side, Vector3(0.24, 0.3, 0.34), Vector3(side * 0.44, 1.12, 0), leather)
		part("Hand%d" % side, Vector3(0.25, 0.3, 0.27), Vector3(side * 0.45, 0.83, -0.03), skin)
		var leg := Node3D.new()
		leg.name = "Leg%d" % side
		leg.position = Vector3(side * 0.19, 0.6, 0)
		add_child(leg)
		legs.append(leg)
		var boot := Factory.create_box(Vector3(0.3, 0.32, 0.48), Color("49342c"))
		boot.position = Vector3(0, -0.43, -0.06)
		leg.add_child(boot)
		var trouser := Factory.create_box(Vector3(0.25, 0.32, 0.29), Color("303d50"))
		trouser.position.y = -0.15
		leg.add_child(trouser)
	part("Scarf", Vector3(0.74, 0.19, 0.53), Vector3(0, 1.35, 0), Color("1796b6"))
	var tail := part("ScarfTail", Vector3(0.3, 0.55, 0.08), Vector3(-0.16, 1.13, 0.32), Color("11728e"))
	tail.rotation.z = -0.25
	variant_nodes.swordsman.append(part("LongHair", Vector3(0.72, 0.95, 0.15), Vector3(0, 1.3, 0.38), Color("d5d8e4")))
	for side in [-1, 1]:
		var coat := part("Coat%d" % side, Vector3(0.3, 0.7, 0.4), Vector3(side * 0.23, 0.52, 0.1), Color("282739"))
		coat.rotation.z = side * 0.12
		variant_nodes.swordsman.append(coat)
		var lock := part("SilverLock%d" % side, Vector3(0.13, 0.65, 0.15), Vector3(side * 0.36, 1.45, -0.12), Color("d5d8e4"))
		variant_nodes.swordsman.append(lock)
		var mantle := part("Mantle%d" % side, Vector3(0.6, 0.23, 0.55), Vector3(side * 0.3, 1.34, 0.12), Color("9d3040"))
		mantle.rotation.z = side * 0.2
		variant_nodes.rift_warden.append(mantle)
		var cape := part("Cape%d" % side, Vector3(0.62, 1.15, 0.08), Vector3(side * 0.25, 0.85, 0.41), Color("842a3e"))
		cape.rotation.z = side * 0.15
		variant_nodes.rift_warden.append(cape)
	variant_nodes.swordsman.append(part("ShoulderGuard", Vector3(0.35, 0.22, 0.48), Vector3(0.4, 1.32, 0), Color("9197aa")))
	variant_nodes.rift_warden.append(part("Mask", Vector3(0.68, 0.6, 0.08), Vector3(0, 1.65, -0.35), Color("dce1d9")))
	variant_nodes.rift_warden.append(part("MaskStripe", Vector3(0.13, 0.6, 0.04), Vector3(0, 1.65, -0.41), Color("25303c")))
	for side in [-1, 1]:
		variant_nodes.rift_warden.append(part("GreenEye%d" % side, Vector3(0.16, 0.09, 0.04), Vector3(side * 0.17, 1.68, -0.41), Color("3ee89f")))
	variant_nodes.rift_warden.append(part("RiftClasp", Vector3(0.18, 0.18, 0.1), Vector3(0, 1.33, -0.3), Color("17b8da")))
	apply_character("melee_hero")

func apply_character(id: String) -> void:
	var silver := id == "swordsman"
	var warden := id == "rift_warden"
	for variant: String in variant_nodes:
		for node: Node3D in variant_nodes[variant]:
			node.visible = variant == id
	for child: Node in get_children():
		if child.name in ["Scarf", "ScarfTail"]:
			child.visible = id == "melee_hero"
		if child is MeshInstance3D:
			var color: Variant = null
			if str(child.name).begins_with("Hair") or str(child.name).begins_with("Fringe"):
				color = Color("d5d8e4") if silver else (Color("252c3b") if warden else Color("493026"))
			elif child.name == "Tunic" or str(child.name).begins_with("Sleeve"):
				color = Color("282739") if silver else (Color("25303c") if warden else Color("80502e"))
			elif str(child.name).begins_with("Hand"):
				color = Color("25303c") if warden else Color("edb47b")
			if color != null:
				child.material_override = Factory.get_shared_material(color)

func _process(delta: float) -> void:
	var body := get_parent() as CharacterBody3D
	if body == null:
		return
	var speed := Vector2(body.velocity.x, body.velocity.z).length()
	phase += delta * minf(speed, 8.0) * 2.2
	for index in legs.size():
		legs[index].rotation.x = sin(phase + index * PI) * minf(speed / 6.0, 1.0) * 0.45
