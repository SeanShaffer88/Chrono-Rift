extends RefCounted
const Bake = preload("res://scripts/utilities/art_mesh.gd")

static func healing(parent: Node3D) -> Node3D:
	var bake := Bake.new()
	bake.pipe(Vector3(0,0.25,0),Vector3(0,0.62,0),0.16,Color("b95b67"))
	bake.pipe(Vector3(0,0.62,0),Vector3(0,0.75,0),0.085,Color("d5bda1"))
	bake.pipe(Vector3(0,0.75,0),Vector3(0,0.83,0),0.1,Color("72513a"))
	bake.box(Vector3(0.26,0.065,0.035),Vector3(0,0.46,-0.16),Color("eee3bd"))
	bake.box(Vector3(0.065,0.25,0.035),Vector3(0,0.46,-0.16),Color("eee3bd"))
	var result := bake.finish(parent,"HealingBottle")
	result.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return result

static func key(parent: Node3D) -> Node3D:
	var bake := Bake.new()
	var gold := Color("e4ba65")
	for index in 12:
		var a := index*TAU/12
		var b := (index+1)*TAU/12
		bake.pipe(Vector3(cos(a)*0.19,1.05+sin(a)*0.19,0),Vector3(cos(b)*0.19,1.05+sin(b)*0.19,0),0.045,gold)
	bake.pipe(Vector3(0,0.45,0),Vector3(0,0.88,0),0.045,gold)
	for y in [0.49,0.61]: bake.box(Vector3(0.2,0.055,0.07),Vector3(0.08,y,0),gold)
	return bake.finish(parent,"GateKeyModel")

static func gate(parent: Node3D) -> ShaderMaterial:
	var bake := Bake.new()
	for side in [-1,1]:
		bake.box(Vector3(0.36,2.4,0.4),Vector3(side*1.0,1.2,0),Color("596b70"))
		for height in [0.15,1.2,2.25]: bake.box(Vector3(0.44,0.12,0.48),Vector3(side*1.0,height,0),Color("b59c67"))
		bake.pipe(Vector3(side*1.0,2.4,0),Vector3(side*0.55,2.85,0),0.16,Color("946443"))
	bake.pipe(Vector3(-0.55,2.85,0),Vector3(0.55,2.85,0),0.16,Color("946443"))
	bake.finish(parent,"RiftGateFrame")
	var plane := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(1.65,2.15)
	plane.mesh = quad
	plane.position.y = 1.2
	plane.name = "RiftGateVeil"
	plane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := ShaderMaterial.new()
	material.shader = preload("res://assets/shaders/rift_gate.gdshader")
	plane.material_override = material
	parent.add_child(plane)
	return material
