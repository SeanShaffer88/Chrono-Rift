extends RefCounted
## Bounded shared folded-card meshes, built on first use; no per-frame baking.
const Bake = preload("res://scripts/utilities/art_mesh.gd")
static var _meshes: Dictionary = {}
static var _materials: Dictionary = {}

static func material(color: Color) -> StandardMaterial3D:
	if not _materials.has(color):
		var value := StandardMaterial3D.new()
		value.albedo_color=color
		value.vertex_color_use_as_albedo=true
		value.roughness=1.0
		_materials[color]=value
	return _materials[color]

static func shape(kind: String) -> Mesh:
	var key := kind if kind in ["head","hair","torso","taper"] else "panel"
	if _meshes.has(key): return _meshes[key]
	var points := PackedVector2Array([Vector2(-0.42,-0.5),Vector2(0.42,-0.5),Vector2(0.5,0.25),Vector2(0.3,0.5),Vector2(-0.3,0.5),Vector2(-0.5,0.25)])
	if key == "torso": points=PackedVector2Array([Vector2(-0.5,-0.5),Vector2(0.5,-0.5),Vector2(0.38,0.5),Vector2(-0.38,0.5)])
	elif key == "head": points=PackedVector2Array([Vector2(-0.36,-0.42),Vector2(0,-0.5),Vector2(0.36,-0.42),Vector2(0.5,0.1),Vector2(0.38,0.5),Vector2(-0.38,0.5),Vector2(-0.5,0.1)])
	elif key == "hair" or key == "taper": points=PackedVector2Array([Vector2(-0.5,-0.4),Vector2(0.45,-0.5),Vector2(0.5,0.2),Vector2(0.05,0.5),Vector2(-0.42,0.3)])
	var bake := Bake.new()
	# A closed folded volume, sandwiched between thin, offset card layers.
	bake.cutout(points,0.80,Transform3D.IDENTITY,Color("d9d4c6"),Color("f2e5cb"))
	for side in [-1,1]:
		var frame := Transform3D(Basis.IDENTITY.scaled(Vector3(0.94,0.94,1)),Vector3(0,0.015,side*0.43))
		bake.cutout(points,0.045,frame,Color.WHITE,Color("f3ead6"))
		# Raised folded seam has real depth on both faces.
		bake.beam(Vector3(-0.21,-0.36,side*0.47),Vector3(-0.13,0.36,side*0.47),0.018,Color("e8dfcc"))
	var holder := Node3D.new()
	_meshes[key]=bake.finish(holder,"FoldedCard").mesh
	holder.free()
	return _meshes[key]

# Hero-only caches: fixed keys keep enemies/legacy fallback forms unchanged.
const HERO_FORMS := ["head","hair","hood","cap","mage_hat","torso","sleeve","bracer","hand","boot","trouser","nose","lock","cloth","shoulder","eye"]
static var _hero_meshes: Dictionary = {}
static var _hero_contours: Dictionary = {}
const CUT_EDGE := Color(1.0,0.89,0.71)

static func hero_shape(kind: String) -> Mesh:
	var key := kind if kind in HERO_FORMS else "torso"
	if _hero_meshes.has(key): return _hero_meshes[key]
	var bake := Bake.new()
	if key=="nose":
		# Compact closed wedge: back sinks into the face, ridge projects forward.
		var outline := PackedVector2Array([Vector2(-0.5,-0.45),Vector2(0.5,-0.45),Vector2(0.30,0.5),Vector2(-0.3,0.5)])
		_ridge(bake,outline,0.45,0.55)
	elif key in ["cloth","eye"]:
		_ridge(bake,PackedVector2Array([Vector2(-0.5,-0.5),Vector2(0.5,-0.5),Vector2(0.43,0.5),Vector2(-0.43,0.5)]),0.5,0.12)
	else:
		var rings: Array[PackedVector3Array] = []
		match key:
			"head":
				rings=[_ring(-0.5,0.66,0.66),_ring(-0.2,0.94,0.94),_ring(0.25,1,1),_ring(0.5,0.84,0.84)]
			"hair":
				rings=[_ring(-0.5,0.88,0.88),_ring(-0.12,1,1),_ring(0.32,0.78,0.76,Vector2(-0.06,0.08)),_ring(0.5,0.25,0.28,Vector2(-0.16,0.12))]
			"hood":
				rings=[_ring(-0.5,0.78,0.83),_ring(-0.15,1,1),_ring(0.29,0.96,0.93,Vector2(0,0.06)),_ring(0.5,0.54,0.58,Vector2(0,0.1))]
			"cap":
				rings=[_ring(-0.45,0.98,0.9),_ring(-0.05,1,0.94,Vector2(0,0.06)),_ring(0.27,0.63,0.57,Vector2(-0.13,0.42)),_ring(-0.25,0.12,0.12,Vector2(-0.27,0.86))]
			"mage_hat":
				rings=[_ring(-0.45,1,0.90),_ring(-0.15,0.82,0.78,Vector2(0,0.02)),_ring(0.18,0.48,0.46,Vector2(-0.10,0.05)),_ring(0.40,0.16,0.18,Vector2(-0.30,0.10)),_ring(0.28,0.04,0.05,Vector2(-0.48,0.12))]
			"lock":
				rings=[_ring(-0.5,0.08,0.2,Vector2(0.18,-0.10)),_ring(-0.08,0.69,0.7),_ring(0.5,1,0.65,Vector2(-0.08,0.06))]
			"boot":
				rings=[_ring(-0.5,1,1.18,Vector2(0,-0.08)),_ring(-0.12,1,1.18,Vector2(0,-0.08)),_ring(0.16,0.72,0.75,Vector2(0,0.12)),_ring(0.5,0.70,0.68,Vector2(0,0.15))]
			"sleeve":
				rings=[_ring(-0.5,0.76,0.8),_ring(-0.14,0.96,0.98),_ring(0.28,1,1),_ring(0.5,0.76,0.82)]
			"bracer":
				rings=[_ring(-0.5,0.84,0.92),_ring(-0.3,1,1),_ring(0.3,0.92,0.95),_ring(0.5,1,1)]
			"hand":
				rings=[_ring(-0.5,0.74,0.84),_ring(-0.28,0.95,0.97),_ring(0.34,1,1),_ring(0.5,0.82,0.88)]
			"shoulder":
				rings=[_ring(-0.5,0.8,0.84),_ring(0.10,1.13,1.1),_ring(0.5,0.72,0.8)]
			"trouser":
				rings=[_ring(-0.5,0.73,0.8),_ring(-0.1,0.9,0.92),_ring(0.5,1,1)]
			_:
				rings=[_ring(-0.5,1,1),_ring(-0.22,0.88,0.94),_ring(0.35,0.96,1),_ring(0.5,0.80,0.85)]
		_loft(bake,rings)
	var holder := Node3D.new()
	_hero_meshes[key]=bake.finish(holder,"HeroPaperForm").mesh
	holder.free()
	return _hero_meshes[key]

static func _ring(y: float,x_scale: float,z_scale: float,shift: Vector2 = Vector2.ZERO) -> PackedVector3Array:
	var result := PackedVector3Array()
	for point: Vector2 in [Vector2(-0.34,-0.5),Vector2(0.34,-0.5),Vector2(0.5,-0.28),Vector2(0.5,0.28),Vector2(0.34,0.5),Vector2(-0.34,0.5),Vector2(-0.5,0.28),Vector2(-0.5,-0.28)]:
		result.append(Vector3(point.x*x_scale+shift.x,y,point.y*z_scale+shift.y))
	return result

static func _triangle(bake: RefCounted,a: Vector3,b: Vector3,c: Vector3,color: Color) -> void:
	bake.surface.set_color(color)
	for point in [a,b,c]:
		bake.surface.add_vertex(point)
		bake.vertex_count+=1

static func _loft(bake: RefCounted,rings: Array[PackedVector3Array]) -> void:
	for level in rings.size()-1:
		for sector in 8:
			var next := (sector+1)%8
			var tone := Color.WHITE.darkened(0.045 if sector%3==0 else 0.0)
			_triangle(bake,rings[level][sector],rings[level][next],rings[level+1][sector],tone)
			_triangle(bake,rings[level][next],rings[level+1][next],rings[level+1][sector],tone)
	for top in [false,true]:
		var ring := rings[-1] if top else rings[0]
		var center := Vector3.ZERO
		for point: Vector3 in ring: center+=point/8.0
		for sector in 8:
			if top: _triangle(bake,center,ring[sector],ring[(sector+1)%8],CUT_EDGE)
			else: _triangle(bake,center,ring[(sector+1)%8],ring[sector],CUT_EDGE)

static func hero_contour(key: String,outline: PackedVector2Array,color: Color,edge: Color) -> Mesh:
	var allowed := ["ScarfTail","LongHair","Mask","Cape-1","Cape1","Coat-1","Coat1","Cowl","CapeCenter"]
	if key not in allowed: return hero_shape("cloth")
	if _hero_contours.has(key): return _hero_contours[key]
	var bake := Bake.new()
	_ridge(bake,outline,0.045,0.055,color,edge)
	var holder := Node3D.new()
	_hero_contours[key]=bake.finish(holder,"RidgedCard").mesh
	holder.free()
	return _hero_contours[key]

static func _ridge(bake: RefCounted,outline: PackedVector2Array,depth: float,ridge: float,color: Color = Color.WHITE,edge: Color = CUT_EDGE) -> void:
	var points := PackedVector2Array(outline)
	if Geometry2D.is_polygon_clockwise(points): points.reverse()
	var indices := Geometry2D.triangulate_polygon(points)
	for side in [-1,1]:
		for index in range(0,indices.size(),3):
			var triangle: Array[Vector3] = []
			for offset in 3:
				var p := points[indices[index+offset]]
				triangle.append(Vector3(p.x,p.y,side*(depth/2+ridge*maxf(0,1-absf(p.x)*2))))
			var center := (triangle[0]+triangle[1]+triangle[2])/3
			center.z=side*(depth/2+ridge*maxf(0,1-absf(center.x)*2))
			for sector in 3:
				var tone := color.darkened(0.08 if center.x<0 else 0.0)
				if side==-1: _triangle(bake,triangle[sector],triangle[(sector+1)%3],center,tone)
				else: _triangle(bake,triangle[(sector+1)%3],triangle[sector],center,tone)
	for index in points.size():
		var a := points[index]
		var b := points[(index+1)%points.size()]
		var az := depth/2+ridge*maxf(0,1-absf(a.x)*2)
		var bz := depth/2+ridge*maxf(0,1-absf(b.x)*2)
		_triangle(bake,Vector3(a.x,a.y,-az),Vector3(a.x,a.y,az),Vector3(b.x,b.y,-bz),edge)
		_triangle(bake,Vector3(b.x,b.y,-bz),Vector3(a.x,a.y,az),Vector3(b.x,b.y,bz),edge)

static var _mage_eye_material: StandardMaterial3D
static func mage_eye_material() -> StandardMaterial3D:
	if _mage_eye_material==null:
		_mage_eye_material=StandardMaterial3D.new()
		_mage_eye_material.albedo_color=Color("f7cf74")
		_mage_eye_material.roughness=1.0
		_mage_eye_material.emission_enabled=true
		_mage_eye_material.emission=Color("dba94b")
		_mage_eye_material.emission_energy_multiplier=0.55
	return _mage_eye_material
