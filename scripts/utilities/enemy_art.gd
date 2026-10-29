extends RefCounted
## Shared matte paper-machine geometry. The actor still owns its flash material.
const Bake = preload("res://scripts/utilities/art_mesh.gd")
static var _meshes: Dictionary = {}

static func mesh(biome: String = "foundry", stationary: bool = false) -> Mesh:
	var region := biome if biome in ["foundry","frost","overgrown_rail"] else "foundry"
	var key := region+str(stationary)
	if _meshes.has(key): return _meshes[key]
	var bake := Bake.new()
	var bone := Color("ded6b9")
	var brass := Color("8d946a") if region == "overgrown_rail" else Color("9eaeb2") if region == "frost" else Color("a38b5d")
	var cable := Color("303f42")
	bake.box(Vector3(0.42,0.64,0.32),Vector3(0,0.12,0),cable)
	for side in [-1,1]:
		for row in 4:
			bake.beam(Vector3(side*0.06,0.43-row*0.14,-0.24),Vector3(side*0.32,0.38-row*0.14,-0.16),0.055,bone)
		bake.pipe(Vector3(side*0.34,0.31,0),Vector3(side*0.46,-0.25,-0.08),0.07,brass)
		bake.pipe(Vector3(side*0.2,-0.2,0.02),Vector3(side*0.23,-0.62,0),0.07,cable)
		bake.box(Vector3(0.26,0.18,0.42),Vector3(side*0.23,-0.73,-0.09),brass)
		bake.box(Vector3(0.15,0.18,0.16),Vector3(side*0.43,-0.02,-0.05),bone)
	bake.box(Vector3(0.15,0.29,0.10),Vector3(0,0.13,-0.24),Color("e5ab57"))
	var mask := PackedVector2Array([Vector2(-0.2,-0.16),Vector2(0.02,-0.28),Vector2(0.28,-0.12),Vector2(0.22,0.2),Vector2(-0.25,0.16)])
	bake.cutout(mask,0.3,Transform3D(Basis.IDENTITY,Vector3(0,0.72,-0.01)),bone,Color("f2ead8"))
	for side in [-1,1]: bake.box(Vector3(0.10,0.05,0.025),Vector3(side*0.12,0.74,-0.18),Color("f2b14d"))
	# Asymmetrical cutting arm is visual only; guard's separate club keeps its timing.
	bake.cutout(PackedVector2Array([Vector2(-0.08,-0.22),Vector2(0.19,-0.34),Vector2(0.11,0.12),Vector2(-0.09,0.2)]),0.06,Transform3D(Basis.IDENTITY,Vector3(-0.48,-0.23,-0.12)),brass,bone)
	if stationary:
		bake.pipe(Vector3(0,-0.8,0),Vector3(0,-0.45,0),0.14,brass)
	var holder := Node3D.new()
	_meshes[key]=bake.finish(holder,"Sentry").mesh
	holder.free()
	return _meshes[key]

static func apply(body: MeshInstance3D,biome: String = "foundry",stationary: bool = false) -> void:
	for child: Node in body.get_children(): child.free()
	body.mesh=mesh(biome,stationary)
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo=true
	material.roughness=1.0
	body.material_override=material

static func club_mesh() -> Mesh:
	if _meshes.has("club"): return _meshes.club
	var bake := Bake.new()
	bake.box(Vector3(0.10,0.13,0.80),Vector3.ZERO,Color("37484b"))
	bake.cutout(PackedVector2Array([Vector2(-0.14,-0.28),Vector2(0.26,-0.35),Vector2(0.1,0.3),Vector2(-0.1,0.3)]),0.055,Transform3D(Basis(Vector3.RIGHT,PI/2),Vector3.ZERO),Color("bbb99b"),Color("e5dec6"))
	var holder := Node3D.new()
	_meshes.club=bake.finish(holder,"CuttingTool").mesh
	holder.free()
	return _meshes.club
