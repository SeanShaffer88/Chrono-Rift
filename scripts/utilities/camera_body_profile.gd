extends RefCounted
## Six rest-model probes, attached to cached moving art nodes. Initialization only scans geometry.
var nodes: Array[Node3D] = []
var points: Array[Vector3] = []
var valid := false

func _init(visual: Node3D, core: bool) -> void:
	if core:
		var shell := visual.get_node_or_null("DevourerArt/Shell") as MeshInstance3D
		if shell == null or shell.mesh == null: return
		var faces := shell.mesh.get_faces()
		for height: float in [-0.30 / shell.scale.y, 0.0]:
			var intersections: Array[Vector3] = []
			for index in range(0, faces.size(), 3):
				for edge in 3:
					var a := faces[index + edge]
					var b := faces[index + (edge + 1) % 3]
					if absf(b.y-a.y) < 0.000001: continue
					var t := (height-a.y)/(b.y-a.y)
					if t >= 0.0 and t <= 1.0: intersections.append(a.lerp(b,t))
			if intersections.is_empty(): return
			for direction: Vector3 in [Vector3.LEFT,Vector3.RIGHT,Vector3.FORWARD,Vector3.BACK] if height != 0.0 else [Vector3.LEFT,Vector3.RIGHT]:
				var extreme := intersections[0]
				for candidate in intersections:
					if candidate.dot(direction) > extreme.dot(direction): extreme=candidate
				var inset := 0.01 if height != 0.0 else 0.02
				extreme -= Vector3(extreme.x,0,extreme.z).normalized()*inset/minf(shell.scale.x,shell.scale.z)
				nodes.append(shell)
				points.append(extreme)
	else:
		var boots: Array[MeshInstance3D] = []
		var bounds := AABB()
		var first := true
		for leg: Node3D in visual.legs:
			var boot := leg.get_node("Boot") as MeshInstance3D
			boots.append(boot)
			var local := visual.global_transform.affine_inverse()*boot.global_transform
			for corner in 8:
				var point := local*boot.mesh.get_aabb().get_endpoint(corner)
				if first:
					bounds=AABB(point,Vector3.ZERO)
					first=false
				else: bounds=bounds.expand(point)
		if boots.size()!=2: return
		for x: float in [bounds.position.x+0.015,bounds.end.x-0.015]:
			for z: float in [bounds.position.z+0.015,bounds.end.z-0.015]:
				var point := Vector3(x,bounds.position.y+0.02,z)
				var boot := boots[0] if x<bounds.get_center().x else boots[1]
				# Leg creation order is not an ownership contract; choose the nearest rest boot.
				for candidate in boots:
					var center: Vector3=visual.global_transform.affine_inverse()*candidate.global_position
					var previous: Vector3=visual.global_transform.affine_inverse()*boot.global_position
					if center.distance_squared_to(point)<previous.distance_squared_to(point): boot=candidate
				nodes.append(boot)
				points.append(boot.global_transform.affine_inverse()*visual.global_transform*point)
		var tunic := visual.get_node("Tunic") as MeshInstance3D
		var torso := tunic.mesh.get_aabb()
		for x: float in [torso.position.x+0.02/tunic.scale.x,torso.end.x-0.02/tunic.scale.x]:
			nodes.append(tunic)
			points.append(Vector3(x,torso.get_center().y,torso.get_center().z))
	valid=points.size()==6
	for point in points: valid=valid and point.is_finite()

func write(out: Array[Vector3]) -> bool:
	if not valid: return false
	if out.size()!=6: out.resize(6)
	for index in 6:
		if not is_instance_valid(nodes[index]): return false
		out[index]=nodes[index].global_transform*points[index]
	return true
