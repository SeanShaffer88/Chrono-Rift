extends Node3D
## Original low-poly character art. Collision and combat stay on the parent.
const Factory = preload("res://scripts/utilities/primitive_mesh_factory.gd")
var legs: Array[Node3D] = []
var phase := 0.0

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

func _process(delta: float) -> void:
	var body := get_parent() as CharacterBody3D
	if body == null:
		return
	var speed := Vector2(body.velocity.x, body.velocity.z).length()
	phase += delta * minf(speed, 8.0) * 2.2
	for index in legs.size():
		legs[index].rotation.x = sin(phase + index * PI) * minf(speed / 6.0, 1.0) * 0.45
