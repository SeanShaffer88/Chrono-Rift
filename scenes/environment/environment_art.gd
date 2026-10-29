extends RefCounted
## Seed-stable decoration. Navigation and restored-part ownership remain authoritative.
const Assets = preload("res://scripts/utilities/environment_assets.gd")
const Factory = preload("res://scripts/utilities/primitive_mesh_factory.gd")
const Scenery = preload("res://scripts/utilities/scenery.gd")
const Paper = preload("res://scenes/environment/papercraft.gd")
static var river_material: ShaderMaterial

static func river() -> ShaderMaterial:
	if river_material == null:
		river_material = ShaderMaterial.new()
		river_material.shader = preload("res://assets/shaders/river_surface.gdshader")
	return river_material

static func dungeon(parent: Node3D, walkable: Dictionary, seed_value: int) -> void:
	var root := Node3D.new()
	root.name = "EnvironmentArt"
	parent.add_child(root)
	var plan := dungeon_layout(walkable, seed_value)
	root.add_child(Assets.batch("floor", plan.floors, plan.colors))
	root.add_child(Assets.batch("floor_alt", plan.accents))
	root.add_child(Assets.batch("wall", plan.walls))
	root.add_child(Assets.batch("wall_detail", plan.details))
	root.add_child(Assets.batch("pier", plan.piers))

static func dungeon_layout(walkable: Dictionary, seed_value: int) -> Dictionary:
	var floors: Array[Transform3D] = []
	var floor_colors: Array[Color] = []
	var accents: Array[Transform3D] = []
	var walls: Array[Transform3D] = []
	var details: Array[Transform3D] = []
	var piers: Array[Transform3D] = []
	for cell: Vector2i in walkable:
		var key := posmod(cell.x * 73 + cell.y * 97 + seed_value, 101)
		var center := Vector3(cell.x * 2.0, 0, cell.y * 2.0)
		var shade := 0.88 + (key % 9) * 0.022
		if key % 17 == 0:
			accents.append(Transform3D(Basis(Vector3.UP, (key % 4) * PI / 2).scaled(Vector3(0.5, 0.18, 0.5)), center))
		else:
			floors.append(Transform3D(Basis(Vector3.UP, (key % 4) * PI / 2).scaled(Vector3(0.5, 0.18, 0.5)), center))
			floor_colors.append(Color(shade, shade, shade))
		for direction in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
			if walkable.has(cell + direction):
				continue
			var normal := Vector3(-direction.x, 0, -direction.y)
			var yaw := atan2(normal.x, normal.z) + PI
			var transform := Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3(0.5, 2.8 / 4.24, 0.5)), center + Vector3(direction.x, 0, direction.y) * 2.0)
			if key % 5 == 0:
				details.append(transform)
			else:
				walls.append(transform)
			if key % 11 == 0:
				# Piers sit inside the existing solid boundary cell, not the walk lane.
				piers.append(Transform3D(Basis.IDENTITY.scaled(Vector3(0.22, 0.67, 0.22)), center + Vector3(direction.x, 0, direction.y) * 1.22))
	return {"floors": floors, "colors": floor_colors, "accents": accents, "walls": walls, "details": details, "piers": piers}

static func torch(parent: Node3D, at: Vector3, yaw: float, with_light: bool) -> void:
	var root := Node3D.new()
	root.name = "WallTorch"
	root.position = at
	root.rotation.y = yaw
	parent.add_child(root)
	var plate := Factory.create_box(Vector3(0.24, 0.55, 0.12), Color("46372d"))
	plate.position.y = 1.5
	root.add_child(plate)
	var arm := Factory.create_box(Vector3(0.13, 0.14, 0.4), Color("453c35"))
	arm.position = Vector3(0, 1.3, 0.16)
	root.add_child(arm)
	var flame := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.02
	cone.bottom_radius = 0.14
	cone.height = 0.42
	cone.radial_segments = 7
	flame.mesh = cone
	flame.material_override = Factory.get_shared_material(Color("f9a443"), 0.9, 1.7)
	flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flame.position = Vector3(0, 1.6, 0.31)
	root.add_child(flame)
	if with_light:
		_steam_fittings(root)
		var light := OmniLight3D.new()
		light.light_color = Color("ffc279")
		light.light_energy = 1.8
		light.omni_range = 8.0
		light.position = Vector3(0, 1.75, 0.5)
		root.add_child(light)

static func _steam_fittings(parent: Node3D) -> void:
	var copper := Factory.get_shared_material(Color("815337"))
	var brass := Factory.get_shared_material(Color("b29557"))
	var tube := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.07
	cylinder.bottom_radius = 0.07
	cylinder.height = 2.25
	cylinder.radial_segments = 8
	tube.mesh = cylinder
	tube.material_override = copper
	tube.position = Vector3(0.5, 1.15, 0.10)
	parent.add_child(tube)
	for height in [0.35, 1.15, 2.0]:
		var collar := MeshInstance3D.new()
		var ring := CylinderMesh.new()
		ring.top_radius = 0.105
		ring.bottom_radius = 0.105
		ring.height = 0.1
		ring.radial_segments = 8
		collar.mesh = ring
		collar.material_override = brass
		collar.position = Vector3(0.5, height, 0.1)
		parent.add_child(collar)
	var gauge := Factory.create_box(Vector3(0.26, 0.3, 0.1), Color("b29557"))
	gauge.position = Vector3(0.5, 1.48, 0.21)
	parent.add_child(gauge)
	var dial := Factory.create_box(Vector3(0.19, 0.23, 0.02), Color("e5d7b5"))
	dial.position = Vector3(0.5, 1.48, 0.27)
	parent.add_child(dial)
	var needle := Factory.create_box(Vector3(0.02, 0.085, 0.012), Color("533a2e"))
	needle.position = Vector3(0.52, 1.5, 0.29)
	needle.rotation.z = -0.4
	parent.add_child(needle)
	var steam := MeshInstance3D.new()
	steam.name = "VentSteam"
	var quad := QuadMesh.new()
	quad.size = Vector2(0.6, 0.9)
	steam.mesh = quad
	var steam_material := ShaderMaterial.new()
	steam_material.shader = preload("res://assets/shaders/steam_wisp.gdshader")
	steam.material_override = steam_material
	steam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	steam.position = Vector3(0.5, 2.7, 0.12)
	parent.add_child(steam)

static func town_terrain(parent: Node3D) -> Node3D:
	var root := Node3D.new()
	root.name = "ValleyEnvironment"
	parent.add_child(root)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var coordinates: Array[int] = [-32, -24, -16, -8, -1]
	for value in range(0, 128, 4):
		coordinates.append(value)
	coordinates.append_array([127, 136, 144, 152, 160])
	for z_index in coordinates.size() - 1:
		for x_index in coordinates.size() - 1:
			var x := coordinates[x_index]
			var z := coordinates[z_index]
			var next_x := coordinates[x_index + 1]
			var next_z := coordinates[z_index + 1]
			for point in [Vector2(x, z), Vector2(next_x, z), Vector2(x, next_z), Vector2(next_x, z), Vector2(next_x, next_z), Vector2(x, next_z)]:
				var outside := maxf(0.0, maxf(maxf(-1 - point.x, point.x - 127), maxf(-1 - point.y, point.y - 127)))
				var height := outside * (0.38 + sin(point.x * 0.05 + point.y * 0.03) * 0.16)
				var green := Color("557c43").lerp(Color("79944e"), 0.5 + sin(point.x * 0.12 + sin(point.y * 0.08)) * 0.5)
				var dry := maxf(0.0, sin(point.x * 0.06 - point.y * 0.04) - 0.5) * 0.35
				surface.set_color(green.lerp(Color("ae9c65"), dry))
				surface.add_vertex(Vector3(point.x, height, point.y))
	surface.generate_normals()
	var mesh := surface.commit()
	var material := Factory.get_shared_material(Color.WHITE).duplicate() as StandardMaterial3D
	material.vertex_color_use_as_albedo = true
	material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	var ground := MeshInstance3D.new()
	ground.mesh = mesh
	ground.material_override = material
	root.add_child(ground)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var collision := CollisionShape3D.new()
	collision.shape = mesh.create_trimesh_shape()
	body.add_child(collision)
	root.add_child(body)
	# The perimeter is beyond the buildable region and backed by the valley ridge.
	for edge in [Vector3(-32, 12, 64), Vector3(160, 12, 64), Vector3(64, 12, -32), Vector3(64, 12, 160)]:
		var shape := BoxShape3D.new()
		shape.size = Vector3(2, 40, 194) if edge.x in [-32.0, 160.0] else Vector3(194, 40, 2)
		var barrier := CollisionShape3D.new()
		barrier.shape = shape
		barrier.position = edge
		body.add_child(barrier)
	for index in 28:
		var side := index % 4
		var along := -8.0 + (index / 4) * 23.0
		var at := Vector3(-13 if side == 0 else 140 if side == 1 else along, 0, -13 if side == 2 else 140 if side == 3 else along)
		var distance := maxf(maxf(-1 - at.x, at.x - 127), maxf(-1 - at.z, at.z - 127))
		at.y = distance * (0.38 + sin(at.x * 0.05 + at.z * 0.03) * 0.16)
		Paper.tree(root, at, 2.0 + (index % 3) * 0.45)
		if index % 2 == 0:
			Scenery.add(root, "boulder", at + Vector3(2, -0.3, 2), 2.5)
	_shore(root)
	Paper.apply(root)
	return root

static func _shore(parent: Node3D) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side: int in [-1, 1]:
		var edge := 50.0 + side * 3.0
		for index in 64:
			var z := -1.0 + index * 2.0
			var inner_a := edge - side * (0.25 + sin(index * 1.7) * 0.12)
			var inner_b := edge - side * (0.25 + sin((index + 1) * 1.7) * 0.12)
			var a := Vector3(minf(edge, inner_a), 0.028, z)
			var b := Vector3(maxf(edge, inner_a), 0.028, z)
			var c := Vector3(minf(edge, inner_b), 0.028, z + 2)
			var d := Vector3(maxf(edge, inner_b), 0.028, z + 2)
			for point in [a, b, c, b, d, c]:
				surface.add_vertex(point)
	surface.generate_normals()
	var bank := MeshInstance3D.new()
	bank.mesh = surface.commit()
	var material := Factory.get_shared_material(Color("9b9267")).duplicate() as StandardMaterial3D
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	bank.material_override = material
	parent.add_child(bank)
