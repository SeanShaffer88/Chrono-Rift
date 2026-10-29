extends RefCounted
## Lightweight linked chain and a tapered, curved blade; no extra physics bodies.
const Factory = preload("res://scripts/utilities/primitive_mesh_factory.gd")

static func make() -> Node3D:
	var root := Node3D.new()
	root.name = "ChainBlade"
	for index in 8:
		var link := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.038
		torus.outer_radius = 0.07
		torus.rings = 12
		torus.ring_segments = 6
		link.mesh = torus
		link.material_override = Factory.get_shared_material(Color("82939d"), 0.45)
		link.position.z = 0.4 - index * 0.11
		link.rotation.z = (index % 2) * PI / 2
		root.add_child(link)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side in [-1, 1]:
		for index in 12:
			var a := float(index) / 12 * PI * 0.9
			var b := float(index + 1) / 12 * PI * 0.9
			var inner_a := lerpf(0.23, 0.43, pow(float(index) / 12, 4))
			var inner_b := lerpf(0.23, 0.43, pow(float(index + 1) / 12, 4))
			var points := [Vector3(cos(a) * 0.43, side * 0.035, -0.65 - sin(a) * 0.43), Vector3(cos(b) * 0.43, side * 0.035, -0.65 - sin(b) * 0.43), Vector3(cos(a) * inner_a, side * 0.035, -0.65 - sin(a) * inner_a), Vector3(cos(b) * inner_b, side * 0.035, -0.65 - sin(b) * inner_b)]
			for vertex in ([0, 1, 2, 1, 3, 2] if side == 1 else [2, 1, 0, 2, 3, 1]):
				surface.add_vertex(points[vertex])
	var blade := MeshInstance3D.new()
	surface.generate_normals()
	blade.mesh = surface.commit()
	var material := Factory.get_shared_material(Color("b0c4cd"), 0.35).duplicate() as StandardMaterial3D
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	blade.material_override = material
	root.add_child(blade)
	var mount := Factory.create_box(Vector3(0.5, 0.1, 0.12), Color("4bbba4"))
	mount.position = Vector3(0.2, 0, -0.5)
	mount.rotation.y = 0.58
	root.add_child(mount)
	return root
