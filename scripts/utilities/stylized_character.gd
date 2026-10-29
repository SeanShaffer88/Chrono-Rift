extends Node3D
## Original low-poly character art. Collision and combat stay on the parent.
const Factory = preload("res://scripts/utilities/primitive_mesh_factory.gd")
const Geometry = preload("res://scripts/utilities/paper_geometry.gd")
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
var swallow_time := 0.0
var devourer := false
var variant_nodes: Dictionary = {"melee_hero": [], "swordsman": [], "riftwarden": [], "battlemage": []}

func part(label: String, size: Vector3, at: Vector3, color: Color) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var kind := "head" if label=="Head" else "hair" if label.begins_with("Hair") else "lock" if label.begins_with("Fringe") or label.begins_with("SilverLock") or label.begins_with("SilverBackLock") else "sleeve" if label.begins_with("Sleeve") else "bracer" if label.begins_with("Bracer") else "hand" if label.begins_with("Hand") else "nose" if label=="Nose" else "shoulder" if label.begins_with("Mantle") or label=="ShoulderGuard" else "eye" if label.begins_with("Eye") or label.begins_with("MageEye") or label.begins_with("Brow") or label.begins_with("Lid") or label.begins_with("GreenEye") or label=="Mouth" else "torso" if label in ["Tunic","Belt","Scarf"] else "cloth"
	mesh.mesh = Geometry.hero_shape(kind)
	mesh.scale = size
	mesh.material_override = Geometry.material(color)
	mesh.name = label
	mesh.position = at
	add_child(mesh)
	return mesh

func _ready() -> void:
	# Preserve inherited node paths for combat and existing scenes.
	$Body.hide()
	$Face.hide()
	owner_body = get_parent() as CharacterBody3D
	var leather := Color("4b7941")
	var skin := Color("edb47b")
	part("Tunic", Vector3(0.65, 0.65, 0.4), Vector3(0, 0.95, 0), leather)
	part("Belt", Vector3(0.69, 0.11, 0.44), Vector3(0, 0.7, 0), Color("392c2c"))
	part("Buckle", Vector3(0.16, 0.12, 0.06), Vector3(0, 0.7, -0.25), Color("d6a652"))
	part("Head", Vector3(0.7,0.62,0.6), Vector3(0, 1.65, -0.02), skin)
	part("Nose",Vector3(0.08,0.10,0.075),Vector3(0,1.62,-0.33),skin)
	part("Mouth",Vector3(0.10,0.025,0.025),Vector3(0,1.51,-0.3),Color("805344"))
	part("Hair", Vector3(0.84,0.38,0.73),Vector3(0,1.96,0.03), Color("c8aa55"))
	part("HairBack", Vector3(0.75, 0.42, 0.2), Vector3(0, 1.75, 0.3), Color("c8aa55"))
	for index in 3:
		var tuft := part("HairTuft%d" % index, Vector3(0.3, 0.16, 0.42), Vector3((index - 1) * 0.19, 2.035, 0.04), Color("d8bf6e"))
		tuft.rotation.z = (index - 1) * 0.45
		tuft.rotation.x = -0.35
	for side in [-1, 1]:
		var fringe := part("Fringe%d" % side, Vector3(0.18,0.29,0.14),Vector3(side*0.26,1.85,-0.27), Color("d8bf6e"))
		fringe.rotation.z = side*0.15
		part("Eye%d" % side, Vector3(0.048,0.075,0.012),Vector3(side*0.145,1.65,-0.315), Color("242739"))
		part("EyeWhite%d" % side,Vector3(0.095,0.084,0.012),Vector3(side*0.145,1.65,-0.305),Color("eee4d0"))
		var brow := part("Brow%d" % side,Vector3(0.13,0.026,0.024),Vector3(side*0.145,1.745,-0.30),Color("c8aa55"))
		brow.rotation.z = side*0.13
		part("Lid%d" % side,Vector3(0.105,0.016,0.014),Vector3(side*0.145,1.695,-0.32),skin.darkened(0.1))
		part("Sleeve%d" % side, Vector3(0.24, 0.3, 0.34), Vector3(side * 0.44, 1.12, 0), leather)
		part("Hand%d" % side, Vector3(0.25, 0.3, 0.27), Vector3(side * 0.45, 0.83, -0.03), skin)
		part("Bracer%d" % side,Vector3(0.27,0.15,0.29),Vector3(side*0.45,0.94,-0.025),Color("64503b"))
		var leg := Node3D.new()
		leg.name = "Leg%d" % side
		leg.position = Vector3(side * 0.19, 0.6, 0)
		add_child(leg)
		legs.append(leg)
		var boot := Factory.create_box(Vector3(0.3, 0.32, 0.48), Color("49342c"))
		boot.mesh = Geometry.hero_shape("boot")
		boot.scale = Vector3(0.32,0.32,0.48)
		boot.name = "Boot"
		boot.position = Vector3(0, -0.43, -0.06)
		leg.add_child(boot)
		var trouser := Factory.create_box(Vector3(0.25, 0.32, 0.29), Color("bca67a"))
		trouser.mesh = Geometry.hero_shape("trouser")
		trouser.scale = Vector3(0.27,0.34,0.32)
		trouser.name = "Trouser"
		trouser.position.y = -0.15
		leg.add_child(trouser)
	for index in 4:
		var lock := part("FringeFront%d" % index,Vector3(0.17,0.27,0.13),Vector3((index-1.5)*0.12,1.87,-0.335),Color("d8bf6e"))
		lock.rotation.z=(index-1.5)*-0.08
	part("Scarf", Vector3(0.74, 0.19, 0.53), Vector3(0, 1.35, 0), Color("1796b6"))
	var tail := part("ScarfTail", Vector3(0.3, 0.55, 0.08), Vector3(-0.16, 1.13, 0.32), Color("11728e"))
	tail.rotation.z = -0.25
	variant_nodes.swordsman.append(part("LongHair", Vector3(0.72, 0.95, 0.15), Vector3(0, 1.3, 0.38), Color("d5d8e4")))
	for index in 3:
		var lock := part("SilverBackLock%d" % index,Vector3(0.34,0.80,0.18),Vector3((index-1)*0.24,1.55,0.36),Color("d5d8e4"))
		lock.rotation.z=(index-1)*0.13
		variant_nodes.swordsman.append(lock)
	for side in [-1, 1]:
		var lapel := part("Lapel%d" % side,Vector3(0.15,0.39,0.055),Vector3(side*0.13,1.12,-0.215),Color("535363"))
		lapel.rotation.z=side*0.32
		variant_nodes.swordsman.append(lapel)
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
	var cap := part("PointedCap",Vector3(0.90,0.40,0.85),Vector3(0,2.11,0.03),Color("4b7941"))
	cap.mesh=Geometry.hero_shape("cap")
	variant_nodes.melee_hero.append(cap)
	var shield := part("BackShield",Vector3.ONE,Vector3(0.04,1.02,0.36),Color("8f714a"))
	var shield_bake := Bake.new()
	shield_bake.cutout(PackedVector2Array([Vector2(-0.28,-0.1),Vector2(0,-0.36),Vector2(0.28,-0.1),Vector2(0.25,0.3),Vector2(-0.25,0.3)]),0.075,Transform3D.IDENTITY,Color("93734e"),Color("e1cfaa"))
	shield_bake.cutout(PackedVector2Array([Vector2(-0.12,0.03),Vector2(0,-0.18),Vector2(0.14,0.03),Vector2(0,0.23)]),0.014,Transform3D(Basis.IDENTITY,Vector3(0,0,-0.05)),Color("4c9c8d"),Color("e5dcc5"))
	# Rear mounting pad and leather straps bridge to the torso, purely cosmetic.
	shield_bake.box(Vector3(0.16,0.18,0.14),Vector3(0,0,0.11),Color("5c4938"))
	for side in [-1,1]:
		shield_bake.beam(Vector3(side*0.15,-0.2,-0.047),Vector3(side*0.11,0.22,-0.047),0.035,Color("594737"))
	var shield_mesh := shield_bake.finish(self,"ShieldBake")
	shield.mesh=shield_mesh.mesh
	shield.material_override=shield_mesh.material_override
	shield_mesh.free()
	shield.rotation=Vector3(0,PI,-0.28)
	variant_nodes.melee_hero.append(shield)
	# Replace hanging blocks with thick, original cut silhouettes.
	_contour($ScarfTail,PackedVector2Array([Vector2(-0.15,0.28),Vector2(0.15,0.28),Vector2(0.22,-0.27),Vector2(0.04,-0.2),Vector2(-0.1,-0.34)]),Color("187d97"),Color("379db0"))
	_contour($LongHair,PackedVector2Array([Vector2(-0.35,0.5),Vector2(0.35,0.5),Vector2(0.38,-0.45),Vector2(0.13,-0.33),Vector2(0,-0.55),Vector2(-0.2,-0.38),Vector2(-0.35,-0.46)]),Color("cbd0df"),Color("9ca5ba"))
	_contour($Mask,PackedVector2Array([Vector2(-0.31,0.26),Vector2(0,0.33),Vector2(0.31,0.26),Vector2(0.27,-0.1),Vector2(0,-0.34),Vector2(-0.27,-0.1)]),Color("d9dfd4"),Color("a6afad"))
	for side: int in [-1,1]:
		_contour(get_node("Cape%d" % side),PackedVector2Array([Vector2(-0.28,0.55),Vector2(0.28,0.55),Vector2(0.4,-0.3),Vector2(0.15,-0.2),Vector2(0.2,-0.6),Vector2(-0.08,-0.43),Vector2(-0.28,-0.55)]),Color("91384b"),Color("ad5060"))
		_contour(get_node("Coat%d" % side),PackedVector2Array([Vector2(-0.16,0.35),Vector2(0.16,0.35),Vector2(0.22,-0.25),Vector2(0,-0.42),Vector2(-0.19,-0.3)]),Color("343142"),Color("756989"))
	var cowl := part("Cowl",Vector3.ONE,Vector3(0,1.31,0.26),Color("9d3040"))
	_contour(cowl,PackedVector2Array([Vector2(-0.41,0.12),Vector2(0.41,0.12),Vector2(0.26,-0.13),Vector2(0,-0.23),Vector2(-0.26,-0.13)]),Color("a43e4c"),Color("bd7370"))
	variant_nodes.riftwarden.append(cowl)
	var cape_center := part("CapeCenter",Vector3.ONE,Vector3(0,0.86,0.47),Color("812b3c"))
	_contour(cape_center,PackedVector2Array([Vector2(-0.24,0.5),Vector2(0.24,0.5),Vector2(0.3,-0.35),Vector2(0,-0.62),Vector2(-0.28,-0.3)]),Color("812b3c"),Color("b66a69"))
	variant_nodes.riftwarden.append(cape_center)
	# Battlemage reuses closed paper forms; no spell/ranged mechanics are added.
	var mage_face := part("MageFace",Vector3(0.59,0.36,0.10),Vector3(0,1.64,-0.32),Color("151b22"))
	variant_nodes.battlemage.append(mage_face)
	var mage_hat := part("MageHat",Vector3(0.95,1.0,1.05),Vector3(0,2.24,0.05),Color("c39759"))
	mage_hat.mesh=Geometry.hero_shape("mage_hat")
	variant_nodes.battlemage.append(mage_hat)
	var mage_brim := part("MageBrim",Vector3(1.14,0.075,0.96),Vector3(0,1.90,0.01),Color("b98a50"))
	mage_brim.mesh=Geometry.hero_shape("bracer")
	variant_nodes.battlemage.append(mage_brim)
	for side in [-1,1]:
		var mage_eye := part("MageEye%d" % side,Vector3(0.065,0.11,0.014),Vector3(side*0.125,1.65,-0.37),Color("f7cf74"))
		mage_eye.material_override=Geometry.mage_eye_material()
		variant_nodes.battlemage.append(mage_eye)
		var mage_coat := part("MageCoat%d" % side,Vector3(0.39,0.75,0.09),Vector3(side*0.20,0.65,-0.17),Color("3e5b84"))
		mage_coat.rotation.z=side*0.09
		variant_nodes.battlemage.append(mage_coat)
		var mage_collar := part("MageCollar%d" % side,Vector3(0.27,0.24,0.10),Vector3(side*0.17,1.35,-0.17),Color("587192"))
		mage_collar.rotation.z=side*0.30
		variant_nodes.battlemage.append(mage_collar)
	add_child(preload("res://scripts/utilities/devourer_art.gd").make())
	$DevourerArt.hide()
	_fit_face()
	for node: Node in get_children():
		if node is MeshInstance3D and node.name not in ["Body","Face"]:
			pose_parts.append(node)
			rest_poses.append(node.transform)
			var label := str(node.name)
			var arm := label.begins_with("Sleeve") or label.begins_with("Hand") or label.begins_with("Bracer")
			pose_roles.append((1 if label.ends_with("-1") else 2) if arm else 3 if label.begins_with("Cape") or label.begins_with("Coat") or label.begins_with("MageCoat") or label in ["ScarfTail","LongHair"] else 0)
	if owner_body != null and owner_body.has_signal("damaged"):
		owner_body.damaged.connect(func(): recoil = 1.0)
	apply_character("melee_hero")

func _contour(node: MeshInstance3D, points: PackedVector2Array, color: Color, edge: Color) -> void:
	node.mesh=Geometry.hero_contour(str(node.name),points,color,edge)
	node.material_override=Geometry.material(Color.WHITE)
	node.scale=Vector3.ONE

func _surface_z(node: MeshInstance3D,x: float,y: float) -> float:
	var faces := node.mesh.get_faces()
	var result := INF
	for index in range(0,faces.size(),3):
		var hit: Variant = Geometry3D.ray_intersects_triangle(Vector3(x,y,-2),Vector3.BACK,node.transform*faces[index],node.transform*faces[index+1],node.transform*faces[index+2])
		if hit is Vector3: result=minf(result,hit.z)
	return result if is_finite(result) else node.position.z-node.scale.z*0.5

func _fit_face() -> void:
	for child: Node in get_children():
		if child is MeshInstance3D:
			var label := str(child.name)
			if label.begins_with("Eye") or label.begins_with("Brow") or label.begins_with("Lid") or label=="Mouth":
				child.position.z=_surface_z($Head,child.position.x,child.position.y)-(0.012 if label.begins_with("Eye") and not label.begins_with("EyeWhite") else 0.005)
	$Nose.position.z=_surface_z($Head,0,$Nose.position.y)+0.012
	$Mask.position.z=-0.405
	for side in [-1,1]:
		var eye: MeshInstance3D=get_node("GreenEye%d" % side)
		eye.scale.z=0.018
		eye.position.z=_surface_z($Mask,eye.position.x,eye.position.y)-0.006
		var mage_eye: MeshInstance3D=get_node("MageEye%d" % side)
		mage_eye.position.z=_surface_z($MageFace,mage_eye.position.x,mage_eye.position.y)-0.006

func apply_character(id: String) -> void:
	devourer = id=="devourer"
	for node: Node3D in get_children():
		if node.name not in ["Body","Face","WeaponPivot"]: node.visible=true
	$Body.hide()
	$Face.hide()
	var silver := id == "swordsman"
	var warden := id == "riftwarden"
	var mage := id == "battlemage"
	for variant: String in variant_nodes:
		for node: Node3D in variant_nodes[variant]:
			node.visible = variant == id
	for child: Node in get_children():
		if child.name in ["Scarf", "ScarfTail"]:
			child.visible = false
		if child is MeshInstance3D:
			if str(child.name).begins_with("Eye") or str(child.name).begins_with("Lid") or child.name in ["Nose","Mouth"]: child.visible = not warden and not mage
			if str(child.name).begins_with("Fringe") or str(child.name).begins_with("Brow"): child.visible = not warden and not mage
			if child.name == "HairBack" or str(child.name).begins_with("HairTuft"): child.visible = false
			if child.name=="MaskStripe": child.visible=false
			if child.name=="Hair":
				child.visible=not mage
				child.mesh=Geometry.hero_shape("hood" if warden else "hair")
				var hair_scale := Vector3(0.90,0.74,0.80) if warden else Vector3(0.78,0.32,0.69) if silver else Vector3(0.84,0.38,0.73)
				var hair_at := Vector3(0,1.84,0.05) if warden else Vector3(0,1.98,-0.02) if silver else Vector3(0,1.96,0.03)
				child.transform=Transform3D(Basis.IDENTITY.scaled(hair_scale),hair_at)
				var pose_index := pose_parts.find(child)
				if pose_index>=0: rest_poses[pose_index]=child.transform
			if str(child.name).begins_with("FringeFront"):
				var lock_index := int(str(child.name).trim_prefix("FringeFront"))
				var lock_at := Vector3((lock_index-1.5)*0.12,1.87,-0.335)
				var lock_size := Vector3(0.17,0.27,0.13)
				var lock_angle := (lock_index-1.5)*-0.08
				if silver:
					var poses := [Vector4(-0.18,1.865,0.25,-0.30),Vector4(-0.05,1.885,0.24,0.24),Vector4(0.09,1.885,0.22,-0.18),Vector4(0.21,1.865,0.28,0.30)]
					var pose: Vector4=poses[lock_index]
					lock_at=Vector3(pose.x,pose.y,-0.335 if lock_index%2==0 else -0.35)
					lock_size=Vector3(0.20 if lock_index==1 else 0.16 if lock_index==2 else 0.18,pose.z,0.28 if lock_index==1 else 0.24 if lock_index==2 else 0.26)
					lock_angle=pose.w
				child.transform=Transform3D(Basis(Vector3.BACK,lock_angle).scaled(lock_size),lock_at)
				var pose_index := pose_parts.find(child)
				if pose_index>=0: rest_poses[pose_index]=child.transform
			var color: Variant = null
			if str(child.name).begins_with("Hair") or str(child.name).begins_with("Fringe") or str(child.name).begins_with("Brow"):
				color = Color("d5d8e4") if silver else (Color("252c3b") if warden else Color("c8aa55"))
			elif child.name == "Tunic" or str(child.name).begins_with("Sleeve"):
				color = Color("282739") if silver else (Color("25303c") if warden else Color("3d557b") if mage else Color("4b7941"))
			elif str(child.name).begins_with("Hand"):
				color = Color("25303c") if warden else Color("76543b") if mage else Color("edb47b")
			elif child.name == "Head" or str(child.name).begins_with("Ear"):
				color = Color("29313c") if warden else Color("151b22") if mage else Color("edb47b")
			elif str(child.name).begins_with("Bracer"):
				color = Color("6c777b") if warden else Color("777c91") if silver else Color("dccba2") if mage else Color("64503b")
			if color != null:
				child.material_override = Geometry.material(color)
	for leg: Node3D in legs:
		leg.get_node("Boot").material_override = Geometry.material(Color("303641") if warden else Color("3b3645") if silver else Color("49342c"))
		leg.get_node("Trouser").material_override = Geometry.material(Color("29313c") if warden else Color("34313f") if silver else Color("bca67a"))
	if devourer:
		for node: Node3D in get_children():
			if node.name not in ["DevourerArt","WeaponPivot"]: node.hide()
	$DevourerArt.visible=devourer
	reset_motion()

func swallow_cue() -> void:
	swallow_time=0.22

func reset_motion() -> void:
	phase = 0.0
	recoil = 0.0
	_apply_pose(Motion.sample(0,0,0,0,1,0,false,pose_buffer))

func _process(delta: float) -> void:
	var body := get_parent() as CharacterBody3D
	if body == null:
		return
	swallow_time=maxf(0,swallow_time-delta)
	$DevourerArt/Jaw.rotation.x=-sin(swallow_time/0.22*PI)*0.45
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
