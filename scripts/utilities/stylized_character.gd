extends Node3D
## Original low-poly character art. Collision and combat stay on the parent.
const Factory = preload("res://scripts/utilities/primitive_mesh_factory.gd")
const Geometry = preload("res://scripts/utilities/hero_geometry.gd")
const Motion = preload("res://scripts/utilities/character_motion.gd")
const Bake = preload("res://scripts/utilities/art_mesh.gd")
var pose_parts: Array[Node3D] = []
var rest_poses: Array[Transform3D] = []
var recoil := 0.0
var owner_body: CharacterBody3D
const PHASE_KEYS := ["windup","active","recovery"]
var pose_roles: Array[int] = [] # 0 body, 1 left arm, 2 right arm, 3 cloth
var pose_buffer: Dictionary = {}
var legs: Array[Node3D] = []
var phase := 0.0
var variant_nodes: Dictionary = {"swordsman": [], "riftwarden": []}

func part(label: String, size: Vector3, at: Vector3, color: Color) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var kind := "head" if label == "Head" else "hair" if label == "Hair" else "taper" if label.begins_with("HairTuft") or label.begins_with("Fringe") else "torso" if label in ["Tunic","Belt","Scarf"] else "round"
	mesh.mesh = Geometry.shape(kind)
	mesh.scale = size
	mesh.material_override = Factory.get_shared_material(color)
	mesh.name = label
	mesh.position = at
	add_child(mesh)
	return mesh

func _ready() -> void:
	# Preserve inherited node paths for combat and existing scenes.
	$Body.hide()
	$Face.hide()
	owner_body = get_parent() as CharacterBody3D
	var leather := Color("80502e")
	var skin := Color("edb47b")
	part("Tunic", Vector3(0.65, 0.65, 0.4), Vector3(0, 0.95, 0), leather)
	part("Belt", Vector3(0.69, 0.11, 0.44), Vector3(0, 0.7, 0), Color("392c2c"))
	part("Buckle", Vector3(0.16, 0.12, 0.06), Vector3(0, 0.7, -0.25), Color("d6a652"))
	part("Head", Vector3(0.7, 0.62, 0.6), Vector3(0, 1.65, -0.02), skin)
	part("Nose",Vector3(0.08,0.10,0.075),Vector3(0,1.62,-0.33),skin)
	part("Mouth",Vector3(0.10,0.025,0.025),Vector3(0,1.51,-0.3),Color("805344"))
	part("Hair", Vector3(0.84, 0.48, 0.75), Vector3(0, 1.91, 0.02), Color("493026"))
	part("HairBack", Vector3(0.75, 0.42, 0.2), Vector3(0, 1.75, 0.3), Color("493026"))
	for index in 3:
		var tuft := part("HairTuft%d" % index, Vector3(0.3, 0.16, 0.42), Vector3((index - 1) * 0.19, 2.035, 0.04), Color("593729"))
		tuft.rotation.z = (index - 1) * 0.45
		tuft.rotation.x = -0.35
	for side in [-1, 1]:
		var fringe := part("Fringe%d" % side, Vector3(0.27, 0.21, 0.17), Vector3(side * 0.23, 1.89, -0.27), Color("593729"))
		fringe.rotation.z = PI + side * 0.2
		part("Eye%d" % side, Vector3(0.055, 0.09, 0.018), Vector3(side * 0.17, 1.65, -0.315), Color("242739"))
		part("EyeWhite%d" % side,Vector3(0.095,0.10,0.018),Vector3(side*0.17,1.65,-0.305),Color("eee4d0"))
		var brow := part("Brow%d" % side,Vector3(0.16,0.035,0.04),Vector3(side*0.17,1.76,-0.30),Color("493026"))
		brow.rotation.z = side*0.13
		part("Sleeve%d" % side, Vector3(0.24, 0.3, 0.34), Vector3(side * 0.44, 1.12, 0), leather)
		part("Hand%d" % side, Vector3(0.25, 0.3, 0.27), Vector3(side * 0.45, 0.83, -0.03), skin)
		part("Bracer%d" % side,Vector3(0.27,0.15,0.29),Vector3(side*0.45,0.94,-0.025),Color("64503b"))
		var leg := Node3D.new()
		leg.name = "Leg%d" % side
		leg.position = Vector3(side * 0.19, 0.6, 0)
		add_child(leg)
		legs.append(leg)
		var boot := Factory.create_box(Vector3(0.3, 0.32, 0.48), Color("49342c"))
		boot.mesh = Geometry.shape("round")
		boot.scale = Vector3(0.32,0.32,0.48)
		boot.name = "Boot"
		boot.position = Vector3(0, -0.43, -0.06)
		leg.add_child(boot)
		var trouser := Factory.create_box(Vector3(0.25, 0.32, 0.29), Color("303d50"))
		trouser.mesh = Geometry.shape("torso")
		trouser.scale = Vector3(0.27,0.34,0.32)
		trouser.name = "Trouser"
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
		variant_nodes.riftwarden.append(mantle)
		var cape := part("Cape%d" % side, Vector3(0.62, 1.15, 0.08), Vector3(side * 0.25, 0.85, 0.41), Color("842a3e"))
		cape.rotation.z = side * 0.15
		variant_nodes.riftwarden.append(cape)
	variant_nodes.swordsman.append(part("ShoulderGuard", Vector3(0.35, 0.22, 0.48), Vector3(0.4, 1.32, 0), Color("9197aa")))
	variant_nodes.riftwarden.append(part("Mask", Vector3(0.68, 0.6, 0.08), Vector3(0, 1.65, -0.35), Color("dce1d9")))
	variant_nodes.riftwarden.append(part("MaskStripe", Vector3(0.13, 0.6, 0.04), Vector3(0, 1.65, -0.41), Color("25303c")))
	for side in [-1, 1]:
		variant_nodes.riftwarden.append(part("GreenEye%d" % side, Vector3(0.13, 0.04, 0.025), Vector3(side * 0.17, 1.7, -0.41), Color("5ac798")))
	variant_nodes.riftwarden.append(part("RiftClasp", Vector3(0.18, 0.18, 0.1), Vector3(0, 1.33, -0.3), Color("17b8da")))
	var strap := part("ChestStrap",Vector3(0.10,0.64,0.045),Vector3(0.04,1.02,-0.218),Color("42342e"))
	strap.rotation.z = -0.52
	part("StrapBuckle",Vector3(0.14,0.13,0.055),Vector3(0.07,1.05,-0.25),Color("b79a61"))
	for side in [-1,1]:
		part("Knee%d" % side,Vector3(0.22,0.18,0.10),Vector3(side*0.19,0.43,-0.15),Color("54483b"))
	# Replace hanging blocks with thick, original cut silhouettes.
	_contour($ScarfTail,PackedVector2Array([Vector2(-0.15,0.28),Vector2(0.15,0.28),Vector2(0.22,-0.27),Vector2(0.04,-0.2),Vector2(-0.1,-0.34)]),Color("187d97"),Color("379db0"))
	_contour($LongHair,PackedVector2Array([Vector2(-0.35,0.5),Vector2(0.35,0.5),Vector2(0.38,-0.45),Vector2(0.13,-0.33),Vector2(0,-0.55),Vector2(-0.2,-0.38),Vector2(-0.35,-0.46)]),Color("cbd0df"),Color("9ca5ba"))
	_contour($Mask,PackedVector2Array([Vector2(-0.31,0.26),Vector2(0,0.33),Vector2(0.31,0.26),Vector2(0.27,-0.1),Vector2(0,-0.34),Vector2(-0.27,-0.1)]),Color("d9dfd4"),Color("a6afad"))
	for side: int in [-1,1]:
		_contour(get_node("Cape%d" % side),PackedVector2Array([Vector2(-0.28,0.55),Vector2(0.28,0.55),Vector2(0.4,-0.3),Vector2(0.15,-0.2),Vector2(0.2,-0.6),Vector2(-0.08,-0.43),Vector2(-0.28,-0.55)]),Color("91384b"),Color("ad5060"))
		_contour(get_node("Coat%d" % side),PackedVector2Array([Vector2(-0.16,0.35),Vector2(0.16,0.35),Vector2(0.22,-0.25),Vector2(0,-0.42),Vector2(-0.19,-0.3)]),Color("343142"),Color("756989"))
	for node: Node in get_children():
		if node is MeshInstance3D and node.name not in ["Body","Face"]:
			pose_parts.append(node)
			rest_poses.append(node.transform)
			var label := str(node.name)
			var arm := label.begins_with("Sleeve") or label.begins_with("Hand") or label.begins_with("Bracer")
			pose_roles.append((1 if label.ends_with("-1") else 2) if arm else 3 if label.begins_with("Cape") or label.begins_with("Coat") or label in ["ScarfTail","LongHair"] else 0)
	if owner_body != null and owner_body.has_signal("damaged"):
		owner_body.damaged.connect(func(): recoil = 1.0)
	apply_character("melee_hero")

func _contour(node: MeshInstance3D, points: PackedVector2Array, color: Color, edge: Color) -> void:
	var bake := Bake.new()
	bake.cutout(points,0.075,Transform3D.IDENTITY,color,edge)
	if node.name == "LongHair":
		for x in [-0.21,0,0.21]:
			bake.beam(Vector3(x,0.44,0.045),Vector3(x+0.015,-0.38,0.045),0.018,Color("a2adc1"))
	var mesh := bake.finish(self,"TemporaryContour")
	node.mesh = mesh.mesh
	node.material_override = mesh.material_override
	node.scale = Vector3.ONE
	mesh.free()

func apply_character(id: String) -> void:
	var silver := id == "swordsman"
	var warden := id == "riftwarden"
	for variant: String in variant_nodes:
		for node: Node3D in variant_nodes[variant]:
			node.visible = variant == id
	for child: Node in get_children():
		if child.name in ["Scarf", "ScarfTail"]:
			child.visible = id == "melee_hero"
		if child is MeshInstance3D:
			if str(child.name).begins_with("Eye") or child.name in ["Nose","Mouth"]: child.visible = not warden
			if str(child.name).begins_with("Fringe") or str(child.name).begins_with("Brow"): child.visible = not warden
			if child.name == "HairBack" or str(child.name).begins_with("HairTuft"): child.visible = false
			var color: Variant = null
			if str(child.name).begins_with("Hair") or str(child.name).begins_with("Fringe") or str(child.name).begins_with("Brow"):
				color = Color("d5d8e4") if silver else (Color("252c3b") if warden else Color("493026"))
			elif child.name == "Tunic" or str(child.name).begins_with("Sleeve"):
				color = Color("282739") if silver else (Color("25303c") if warden else Color("80502e"))
			elif str(child.name).begins_with("Hand"):
				color = Color("25303c") if warden else Color("edb47b")
			elif child.name == "Head" or str(child.name).begins_with("Ear"):
				color = Color("29313c") if warden else Color("edb47b")
			elif str(child.name).begins_with("Bracer"):
				color = Color("6c777b") if warden else Color("777c91") if silver else Color("64503b")
			if color != null:
				child.material_override = Factory.get_shared_material(color)
	for leg: Node3D in legs:
		leg.get_node("Boot").material_override = Factory.get_shared_material(Color("303641") if warden else Color("3b3645") if silver else Color("49342c"))
		leg.get_node("Trouser").material_override = Factory.get_shared_material(Color("29313c") if warden else Color("34313f") if silver else Color("303d50"))
	reset_motion()

func reset_motion() -> void:
	phase = 0.0
	recoil = 0.0
	_apply_pose(Motion.sample(0,0,0,0,1,0,false,pose_buffer))

func _process(delta: float) -> void:
	var body := get_parent() as CharacterBody3D
	if body == null:
		return
	var speed := Vector2(body.velocity.x, body.velocity.z).length()
	phase += delta * minf(speed, 8.0) * 2.2
	recoil = maxf(0,recoil-maxf(delta,0)*6)
	var raw_state: Variant = body.get("combat_state")
	var state: int = int(raw_state) if raw_state != null else 0
	var progress := 0.0
	var side := 1.0
	if state in [1,2,3]:
		var timings: Dictionary = body._current_step()
		var duration: float = timings[PHASE_KEYS[state-1]]
		progress = clampf(body._state_time/duration,0,1)
		side = -1 if body.combo_step == 1 else 1
	_apply_pose(Motion.sample(speed,phase,state,progress,side,recoil,body.is_dead(),pose_buffer))

func _apply_pose(pose: Dictionary) -> void:
	var pivot := Vector3(0,0.85,0)
	var basis := Basis.from_euler(pose.torso)
	var frame := Transform3D(basis,pivot-basis*pivot+Vector3.UP*float(pose.height))
	for index in pose_parts.size():
		var node := pose_parts[index]
		var rest := rest_poses[index]
		var role := pose_roles[index]
		if role in [1,2]:
			var shoulder := Vector3(-0.44 if role == 1 else 0.44,1.22,0)
			var arm := Basis(Vector3.RIGHT,float(pose.left_arm if role == 1 else pose.right_arm))
			node.transform = frame*Transform3D(arm,shoulder-arm*shoulder)*rest
		else:
			node.transform = frame*rest
			if role == 3:
				node.rotate_object_local(Vector3.RIGHT,-float(pose.cloth))
	for index in legs.size(): legs[index].rotation.x = pose.stride*(1 if index == 0 else -1)
