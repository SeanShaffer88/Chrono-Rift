extends RefCounted
## Lightweight linked chain and a tapered, curved blade; no extra physics bodies.
const Factory = preload("res://scripts/utilities/primitive_mesh_factory.gd")

static func make() -> Node3D:
	var root := Node3D.new()
	root.name = "ChainBlade"
	var links := MultiMesh.new()
	links.transform_format = MultiMesh.TRANSFORM_3D
	var torus := TorusMesh.new()
	torus.inner_radius = 0.038
	torus.outer_radius = 0.07
	torus.rings = 8
	torus.ring_segments = 6
	links.mesh = torus
	links.instance_count = 8
	for index in 8:
		links.set_instance_transform(index,Transform3D(Basis(Vector3.BACK,(index % 2)*PI/2),Vector3(0,0,0.4-index*0.11)))
	var link_batch := MultiMeshInstance3D.new()
	link_batch.name = "LinkedChain"
	link_batch.multimesh = links
	link_batch.material_override = Factory.get_shared_material(Color("82939d"),0.45)
	root.add_child(link_batch)
	var outline := PackedVector2Array()
	for index in 17:
		var angle := index*PI*0.9/16
		outline.append(Vector2(cos(angle)*0.43,-0.65-sin(angle)*0.43))
	for index in range(15,-1,-1):
		var angle := index*PI*0.9/16
		var radius := lerpf(0.23,0.43,pow(float(index)/16,4))
		outline.append(Vector2(cos(angle)*radius,-0.65-sin(angle)*radius))
	var bake := preload("res://scripts/utilities/art_mesh.gd").new()
	bake.cutout(outline,0.065,Transform3D(Basis(Vector3.RIGHT,PI/2),Vector3.ZERO),Color("c1d1d4"),Color("849ca6"))
	bake.finish(root,"CrescentBlade")
	var mount := Factory.create_box(Vector3(0.22,0.10,0.12),Color("8a7957"))
	mount.position = Vector3(0.32,0,-0.57)
	mount.rotation.y = 0.58
	root.add_child(mount)
	return root
