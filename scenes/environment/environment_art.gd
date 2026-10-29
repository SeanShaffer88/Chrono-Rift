extends RefCounted
## Seed-stable decoration. Navigation and restored-part ownership remain authoritative.
const Assets = preload("res://scripts/utilities/environment_assets.gd")
const Factory = preload("res://scripts/utilities/primitive_mesh_factory.gd")
const Scenery = preload("res://scripts/utilities/scenery.gd")
const Paper = preload("res://scenes/environment/papercraft.gd")
const Bake = preload("res://scripts/utilities/art_mesh.gd")
static var river_material: ShaderMaterial

static func river() -> ShaderMaterial:
	if river_material == null:
		river_material = ShaderMaterial.new()
		river_material.shader = preload("res://assets/shaders/river_surface.gdshader")
	return river_material

static func dungeon(parent: Node3D, walkable: Dictionary, seed_value: int, biome: String = "foundry") -> void:
	biome = preload("res://scripts/utilities/dungeon_biomes.gd").normalized(biome)
	var root := Node3D.new()
	root.name = "EnvironmentArt"
	parent.add_child(root)
	var plan := dungeon_layout(walkable, seed_value)
	root.add_child(Assets.batch("floor", plan.floors, plan.colors))
	root.add_child(Assets.batch("floor_alt", plan.accents))
	root.add_child(Assets.batch("wall", plan.walls))
	root.add_child(Assets.batch("wall_detail", plan.details))
	root.add_child(Assets.batch("pier", plan.piers))
	_flagstones(root,walkable,seed_value,biome)
	_masonry(root, walkable, seed_value,biome)
	_rock_backing(root,walkable,seed_value,biome)
	_region_details(root,walkable,seed_value,biome)

static func paving_layout(walkable: Dictionary, seed_value: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for cell: Vector2i in walkable:
		for row in 2:
			var key := posmod(cell.x*73+cell.y*97+row*31+seed_value,101)
			var split := 0.72 + (key%5)*0.12
			var widths := PackedFloat32Array([1.97]) if key%3 == 0 else PackedFloat32Array([split-0.02,1.97-split])
			var start := -0.985
			for width in widths:
				result.append({"size":Vector3(width,0.045,0.97),"at":Vector3(cell.x*2+start+width/2,0.025,cell.y*2-0.5+row),"color":Color("a48e70").lightened((key%7-3)*0.018)})
				start += width+0.02
	return result

const GROUT_TOP := 0.040
const BACKING_ROOF := 2.25

static func _flagstones(parent: Node3D,walkable: Dictionary,seed_value: int,biome: String = "foundry") -> void:
	# Opaque quiet grout hides source-floor pattern through narrow slab gaps.
	var grout := Bake.new()
	for cell: Vector2i in walkable:
		grout.box(Vector3(2,0.002,2),Vector3(cell.x*2,GROUT_TOP-0.001,cell.y*2),(Color("c3d8d4") if biome == "frost" else Color("7d8973") if biome == "overgrown_rail" else Color("95866f")))
	grout.finish(parent,"QuietGrout")
	var bake := Bake.new()
	for slab: Dictionary in paving_layout(walkable,seed_value):
		var tone: Color = Color("becfc9").lightened((int(slab.at.x)%5)*0.012) if biome == "frost" else Color("859080") if biome == "overgrown_rail" else slab.color
		bake.box(slab.size,slab.at,tone)
	bake.finish(parent,"InsetFlagstones")

static func backing_runs(walkable: Dictionary) -> Array[Rect2i]:
	var result: Array[Rect2i] = []
	if walkable.is_empty(): return result
	var bounds := Rect2i(walkable.keys()[0],Vector2i.ONE)
	for cell: Vector2i in walkable: bounds = bounds.merge(Rect2i(cell,Vector2i.ONE))
	bounds = bounds.grow(3)
	for y in range(bounds.position.y,bounds.end.y):
		var x := bounds.position.x
		while x < bounds.end.x:
			if walkable.has(Vector2i(x,y)):
				x += 1
				continue
			var start := x
			while x < bounds.end.x and not walkable.has(Vector2i(x,y)): x += 1
			result.append(Rect2i(start,y,x-start,1))
	return result

static func rock_boundary_cell(cell: Vector2i,walkable: Dictionary) -> bool:
	if walkable.has(cell): return false
	for y in range(-1,2):
		for x in range(-1,2):
			if walkable.has(cell+Vector2i(x,y)): return true
	return false

static func rock_corner_height(corner: Vector2i,walkable: Dictionary,seed_value: int) -> float:
	# Shared plateau reproduces the old masking envelope over imported wall backs.
	for offset in [Vector2i.ZERO,Vector2i.LEFT,Vector2i.UP,Vector2i(-1,-1)]:
		if rock_boundary_cell(corner+offset,walkable): return 2.72
	var key := posmod(corner.x*73+corner.y*97+seed_value*11,101)/100.0
	return lerpf(2.30,2.60,key)

static func rock_cap_layout(walkable: Dictionary,seed_value: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for run: Rect2i in backing_runs(walkable):
		for x in range(run.position.x,run.end.x):
			var cell := Vector2i(x,run.position.y)
			var points := PackedVector3Array()
			for offset in [Vector2i.ZERO,Vector2i.RIGHT,Vector2i.ONE,Vector2i.DOWN]:
				var corner: Vector2i = cell+offset
				points.append(Vector3(corner.x*2-1,rock_corner_height(corner,walkable,seed_value),corner.y*2-1))
			var key := posmod(cell.x*43+cell.y*61+seed_value*7,101)
			var peak := Vector3(cell.x*2+(key%5-2)*0.13,lerpf(2.32,2.70,key/100.0),cell.y*2+(key%7-3)*0.11)
			# Boundary cells stay near the dressed wall coping, retaining clear lanes.
			if rock_boundary_cell(cell,walkable): peak.y=2.72
			result.append({"cell":cell,"corners":points,"peak":peak,"shade":key})
	return result

static func _rock_backing(parent: Node3D,walkable: Dictionary,seed_value: int,biome: String = "foundry") -> void:
	var slate := Color("9db9bd") if biome == "frost" else Color("405849") if biome == "overgrown_rail" else Color("35464f")
	var bake := Bake.new()
	var runs := backing_runs(walkable)
	for run: Rect2i in runs:
		bake.box(Vector3(run.size.x*2,BACKING_ROOF,2),Vector3((run.position.x+(run.size.x-1)*0.5)*2,BACKING_ROOF/2,run.position.y*2),slate)
	var result := bake.finish(parent,"SolidRockBacking")
	result.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if runs.is_empty(): return
	var cap := Bake.new()
	var patches := rock_cap_layout(walkable,seed_value)
	var cap_cells := {}
	for patch: Dictionary in patches: cap_cells[patch.cell]=true
	for patch: Dictionary in patches:
		var points: PackedVector3Array = patch.corners
		for index in 4:
			cap.surface.set_color((Color("dce6dc") if biome == "frost" else slate).lightened((patch.shade%5-2)*0.012))
			# Clockwise triangles produce upward normals in Godot.
			for point in [points[index],points[(index+1)%4],patch.peak]:
				cap.surface.add_vertex(point)
				cap.vertex_count+=1
			if cap_cells.has(patch.cell+[Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT][index]): continue
			var a := points[index]
			var b := points[(index+1)%4]
			for point in [a,Vector3(a.x,BACKING_ROOF,a.z),b,b,Vector3(a.x,BACKING_ROOF,a.z),Vector3(b.x,BACKING_ROOF,b.z)]:
				cap.surface.add_vertex(point)
				cap.vertex_count+=1
	var cap_mesh := cap.finish(parent,"FacetedSlateCap")
	cap_mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var bounds := Rect2i(runs[0].position,Vector2i.ONE)
	for run: Rect2i in runs: bounds = bounds.merge(run)
	var skyline := Bake.new()
	for side in 4:
		for index in 9:
			var across := lerpf((bounds.position.x if side < 2 else bounds.position.y)*2.0-10,(bounds.end.x if side < 2 else bounds.end.y)*2.0+10,index/8.0)
			var at := Vector3(across,0,bounds.position.y*2-12) if side == 0 else Vector3(across,0,bounds.end.y*2+12) if side == 1 else Vector3(bounds.position.x*2-12,0,across) if side == 2 else Vector3(bounds.end.x*2+12,0,across)
			var height := 7.0+posmod(index*7+side*3,5)
			skyline.box(Vector3(12,height,12),at+Vector3.UP*height/2,(Color("71989f") if biome == "frost" else Color("2c453b") if biome == "overgrown_rail" else Color("293c4a")))
			skyline.box(Vector3(13,0.35,13),at+Vector3.UP*height,(Color("bdd4d2") if biome == "frost" else Color("587451") if biome == "overgrown_rail" else Color("354954")))
	var distant := skyline.finish(parent,"DistantFoundrySilhouette")
	distant.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

static func _region_details(parent: Node3D,walkable: Dictionary,seed_value: int,biome: String) -> void:
	if biome == "foundry" or walkable.is_empty(): return
	var bake := Bake.new()
	for cell: Vector2i in walkable:
		var key := posmod(cell.x*37+cell.y*61+seed_value,23)
		if biome == "overgrown_rail":
			# Shallow fixed rails and sleepers remain cosmetic, below ankle height.
			for side in [-1,1]: bake.box(Vector3(0.045,0.008,1.96),Vector3(cell.x*2+side*0.44,0.052,cell.y*2),Color("806348"))
			for along in [-0.66,0,0.66]: bake.box(Vector3(1.18,0.004,0.11),Vector3(cell.x*2,0.049,cell.y*2+along),Color("6d7057"))
		for direction: Vector2i in [Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT]:
			if walkable.has(cell+direction): continue
			var outside := Vector3((cell.x+direction.x)*2,0,(cell.y+direction.y)*2)
			if biome == "frost":
				var ledge := Vector3(cell.x*2,2.52,cell.y*2)+Vector3(direction.x,0,direction.y)*1.08
				bake.box(Vector3(0.12,0.08,1.86) if direction.x != 0 else Vector3(1.86,0.08,0.12),ledge,Color("e4e8da"))
				if key%3 == 0:
					var frame := Transform3D(Basis(Vector3.UP,atan2(-direction.x,-direction.y)),Vector3(cell.x*2,0,cell.y*2)+Vector3(direction.x,0,direction.y)*1.06)
					bake.cutout(PackedVector2Array([Vector2(-0.25,0.3),Vector2(0.22,0.22),Vector2(0.31,1.12),Vector2(-0.16,1.4)]),0.055,frame,Color("79bec5"),Color("d1e2d9"))
			elif key%3 == 0:
				for leaf in 4:
					var frame := Transform3D(Basis.from_euler(Vector3(0.2,leaf*1.3,0.3)),outside+Vector3(0,1.8+leaf*0.06,0))
					bake.cutout(PackedVector2Array([Vector2(0,-0.17),Vector2(0.35,0.05),Vector2(0,0.52),Vector2(-0.2,0.08)]),0.035,frame,Color("668654"),Color("bdc5a0"))
	var result := bake.finish(parent,"FrostShelves" if biome == "frost" else "RailsAndPaperFoliage")
	result.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

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
			floors.append(Transform3D(Basis(Vector3.UP, (key % 4) * PI / 2).scaled(Vector3(0.5, 0.18, 0.5)), center - Vector3.UP*0.05))
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

static func _masonry(parent: Node3D, walkable: Dictionary, seed_value: int,biome: String = "foundry") -> void:
	var bake := Bake.new()
	for cell: Vector2i in walkable:
		for direction: Vector2i in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
			if walkable.has(cell + direction): continue
			var normal := Vector3(-direction.x,0,-direction.y)
			bake.frame = Transform3D(Basis(Vector3.UP, atan2(normal.x,normal.z)), Vector3(cell.x*2,0,cell.y*2) + Vector3(direction.x,0,direction.y)*1.04)
			# Shallow staggered stone faces use the existing wall for collision.
			for course in 3:
				var tone := (Color("87afb5") if biome == "frost" else Color("5b7060") if biome == "overgrown_rail" else Color("526873")).lightened(posmod(cell.x*7+cell.y*3+course,7)*0.016)
				if course % 2 == 0:
					for x in [-0.5,0.5]: bake.box(Vector3(0.97,0.855,0.075), Vector3(x,0.48+course*0.9,0.02),tone)
				else:
					bake.box(Vector3(0.97,0.855,0.075),Vector3(0,1.38,0.02),tone)
					for x in [-0.76,0.76]: bake.box(Vector3(0.455,0.855,0.075), Vector3(x,1.38,0.02),tone.darkened(0.025))
			bake.box(Vector3(2.0,0.16,0.12), Vector3(0,2.78,0.01), Color("7f8b83"))
			var along: int = cell.x if direction.y != 0 else cell.y
			if posmod(along,3) == 0:
				bake.box(Vector3(0.34,2.8,0.24), Vector3(0,1.4,0.045), Color("73847f"))
				for height in [0.18,2.62]: bake.box(Vector3(0.48,0.24,0.3),Vector3(0,height,0.065),Color("8d998b"))
	var mesh := bake.finish(parent, "MasonryCourses")
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

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
		if index % 3 == 0:
			Paper.round_tree(root, at, 2.3 + (index % 3) * 0.35)
		else:
			Paper.tree(root, at, 2.0 + (index % 3) * 0.45)
		if index % 2 == 0:
			Scenery.add(root, "boulder", at + Vector3(2, -0.3, 2), 2.5)
	_paper_ridges(root)
	_shore(root)
	Paper.apply(root)
	return root

static func _paper_ridges(parent: Node3D) -> void:
	var bake := Bake.new()
	for side in 4:
		var rotation := Basis(Vector3.UP, side * PI / 2)
		for layer in 3:
			var points := PackedVector2Array([Vector2(-82,0),Vector2(82,0)])
			for index in range(12,-1,-1):
				points.append(Vector2(-82 + index*164.0/12, 6.0 + layer*2 + sin(index*1.7 + side)*3.0))
			# Backdrop cards stay beyond physical world boundaries, never walk-through scenery.
			var at := Vector3(64,8 + layer*2,64) + rotation * Vector3(0,0,97 + layer*6)
			bake.cutout(points,0.18,Transform3D(rotation,at),Color("52776b").lerp(Color("92a875"),layer*0.22),Color("c9c29a"))
	bake.finish(parent,"LayeredPaperRidges",Paper.material(Color.WHITE,null,true))

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
