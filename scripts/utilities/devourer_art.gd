extends RefCounted
## Compact original paper mechanism. Cached opaque parts; no gameplay ownership.
const Bake = preload("res://scripts/utilities/art_mesh.gd")
const Paper = preload("res://scripts/utilities/paper_geometry.gd")
static var _meshes: Dictionary = {}
static func make() -> Node3D:
	if _meshes.is_empty():
		var holder := Node3D.new()
		var bake := Bake.new()
		var sphere := SphereMesh.new()
		sphere.radius=0.5
		sphere.height=1.0
		sphere.radial_segments=12
		sphere.rings=6
		var faces := sphere.get_faces()
		bake.surface.set_color(Color.WHITE)
		for index in range(0,faces.size(),3):
			if (faces[index+1]-faces[index]).cross(faces[index+2]-faces[index]).length_squared()<0.0000000001: continue
			for offset in 3:
				bake.surface.add_vertex(faces[index+offset])
				bake.vertex_count+=1
		_meshes.shell=bake.finish(holder,"Shell").mesh
		bake=Bake.new()
		bake.box(Vector3(0.85,0.40,0.10),Vector3(0,1.02,-0.59),Color("161b20"))
		for side in [-1,1]:
			bake.box(Vector3(0.12,0.42,0.12),Vector3(side*0.48,1.03,-0.55),Color("743b38"))
			bake.pipe(Vector3(side*0.52,0.93,-0.10),Vector3(side*0.52,0.93,0.15),0.12,Color("544b3d"))
			bake.box(Vector3(0.13,0.43,0.46),Vector3(side*0.55,1.17,0.08),Color("8e4037"))
		bake.box(Vector3(0.28,0.18,0.045),Vector3(0,1.40,-0.56),Color("544b3d"))
		for index in 5:
			bake.box(Vector3(0.11,0.08,0.08),Vector3((index-2)*0.17,1.20,-0.66),Color("b9aa83"))
		for index in 3:
			bake.box(Vector3(0.10,0.10,0.04),Vector3((index-1)*0.20,1.06,-0.66),Color("514a39"))
		_meshes.face=bake.finish(holder,"Face").mesh
		bake=Bake.new()
		bake.box(Vector3(0.94,0.17,0.65),Vector3(0,0,-0.08),Color("8e4037"))
		for index in 5:
			bake.box(Vector3(0.115,0.11,0.10),Vector3((index-2)*0.17,0.11,-0.34),Color("d7c28d"))
		_meshes.jaw=bake.finish(holder,"Jaw").mesh
		holder.free()
	var root := Node3D.new()
	root.name="DevourerArt"
	var shell := MeshInstance3D.new()
	shell.name="Shell"
	shell.mesh=_meshes.shell
	shell.scale=Vector3(1.18,1.12,1.05)
	shell.position=Vector3(0,1.10,0)
	shell.material_override=Paper.material(Color("bb943b"))
	root.add_child(shell)
	for key: String in ["face","jaw"]:
		var node := MeshInstance3D.new()
		node.name="Jaw" if key=="jaw" else "MouthFrame"
		node.mesh=_meshes[key]
		node.material_override=Paper.material(Color.WHITE)
		if key=="jaw": node.position=Vector3(0,0.83,-0.29)
		root.add_child(node)
	var eye := MeshInstance3D.new()
	eye.name="SingleEye"
	eye.mesh=Paper.hero_shape("eye")
	eye.scale=Vector3(0.18,0.11,0.025)
	eye.position=Vector3(0,1.40,-0.60)
	eye.material_override=Paper.mage_eye_material()
	root.add_child(eye)
	return root
