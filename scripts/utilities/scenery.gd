extends RefCounted
## Explicit, small asset allowlist; never import the entire source catalog.
const MODELS = {
	"tree": preload("res://assets/kenney/fantasy-town/tree.glb"),
	"rock": preload("res://assets/kenney/fantasy-town/rock-small.glb"),
	"boulder": preload("res://assets/kenney/fantasy-town/rock-large.glb"),
	"lantern": preload("res://assets/kenney/fantasy-town/lantern.glb"),
	"banner": preload("res://assets/kenney/fantasy-town/banner-red.glb"),
}

static func add(parent: Node3D, kind: String, at: Vector3, factor: float = 1.0) -> Node3D:
	var model: Node3D = MODELS[kind].instantiate()
	model.position = at
	model.scale = Vector3.ONE * factor
	parent.add_child(model)
	return model
