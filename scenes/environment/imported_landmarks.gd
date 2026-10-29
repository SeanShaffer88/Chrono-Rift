extends RefCounted
## Initialization-only decoration, owned by the floor's DungeonLandmarks node.
const Parts = preload("res://scripts/utilities/landmark_assets.gd")
const Bake = preload("res://scripts/utilities/art_mesh.gd")

static func rail_pair(parent: Node3D,walkable: Dictionary) -> bool:
	if walkable.is_empty(): return false
	var bounds := Rect2i(walkable.keys()[0],Vector2i.ONE)
	for cell: Vector2i in walkable: bounds=bounds.merge(Rect2i(cell,Vector2i.ONE))
	var locomotive := Parts.create("locomotive","overgrown_rail",Vector3(2.6,2.8,4.6))
	var car := Parts.create("coal_car","overgrown_rail",Vector3(2.5,2.6,4.6))
	if locomotive==null or car==null:
		if locomotive!=null: locomotive.free()
		if car!=null: car.free()
		return false
	locomotive.rotation.y=PI/2
	car.rotation.y=PI/2
	var a := Parts.footprint(locomotive)
	var b := Parts.footprint(car)
	var center_x := (bounds.position.x+bounds.end.x-1)*1.0
	var min_walk_z := bounds.position.y*2-1.0
	# Place the entire pair beyond outer map bounds, not over the solid backing.
	var z := min_walk_z-8.0-maxf(a.size.y,b.size.y)/2-0.3
	locomotive.position=Vector3(center_x-(b.size.x+0.4)/2,2.96,z)
	car.position=Vector3(center_x+(a.size.x+0.4)/2,2.96,z)
	var footprint := Parts.footprint(locomotive).merge(Parts.footprint(car)).grow(0.3)
	# Exact footprint-vs-every-cell proof includes the plinth, not merely centers.
	if not Parts.clear_of_walkable(footprint,walkable,7.0):
		locomotive.free()
		car.free()
		return false
	var frame := Node3D.new()
	frame.name="DistantRailLandmark"
	parent.add_child(frame)
	frame.add_child(locomotive)
	frame.add_child(car)
	var bake := Bake.new()
	var center := footprint.get_center()
	bake.box(Vector3(footprint.size.x,0.20,footprint.size.y),Vector3(center.x,2.85,center.y),Color("4b554c"))
	for side in [-1,1]:
		bake.box(Vector3(footprint.size.x,0.025,0.04),Vector3(center.x,2.962,center.y+side*0.55),Color("897052"))
	for index in 5:
		var x := lerpf(footprint.position.x+0.2,footprint.end.x-0.2,index/4.0)
		bake.box(Vector3(0.08,0.025,1.3),Vector3(x,2.963,center.y),Color("6d7055"))
		# Small original folded vine strips stay inside the already checked plinth.
		bake.beam(Vector3(x,2.96,center.y-0.5),Vector3(x+0.12,3.1,center.y-0.4),0.04,Color("73875c"))
	var base := bake.finish(frame,"RaisedRailsAndFoldTrim")
	base.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return true

static func frost_detail(parent: Node3D,anchor: Vector3,id: String) -> bool:
	if id not in ["valve","piston"]: return false
	var part := Parts.create(id,"frost",Vector3.ONE*0.20)
	if part==null: return false
	var height := part.mesh.get_aabb().size.y*part.scale.y
	part.position=anchor+Vector3(0,0.82-height/2,0.03)
	# Compact gauges replace indicator details on the existing cabinet backing.
	var box: AABB = part.transform*part.mesh.get_aabb()
	if box.position.y<anchor.y or box.end.y>2.60 or box.position.z<anchor.z-0.09 or box.end.z>anchor.z+0.14 or box.position.x<anchor.x-0.65 or box.end.x>anchor.x+0.65:
		part.free()
		return false
	parent.add_child(part)
	return true
