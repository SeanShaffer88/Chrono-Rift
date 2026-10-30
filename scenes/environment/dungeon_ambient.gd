extends Node3D
## At most two prebuilt visual targets. No audio, physics or per-frame geometry.
var targets: Array[Dictionary]=[]
var time := 0.0
func add_target(node: Node3D,mode: String,phase: float=0.0) -> bool:
	if targets.size()>=2 or mode not in ["valve","piston","leaf"] or not is_finite(phase): return false
	targets.append({"node":node,"rest":node.transform,"mode":mode,"phase":phase})
	return true
func _process(delta: float) -> void:
	time=fmod(time+delta,TAU*10)
	for item: Dictionary in targets:
		var node: Node3D=item.node
		if not is_instance_valid(node): continue
		node.transform=item.rest
		if item.mode=="valve": node.rotate_object_local(Vector3.BACK,time*0.1+item.phase)
		elif item.mode=="piston": node.position.y+=sin(time*0.6+item.phase)*0.04
		else: node.rotate_object_local(Vector3.BACK,sin(time*0.7+item.phase)*deg_to_rad(2))
func _exit_tree() -> void:
	for item: Dictionary in targets:
		if is_instance_valid(item.node): item.node.transform=item.rest
	targets.clear()
