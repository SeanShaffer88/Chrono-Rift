extends RefCounted
## Legacy rift_chain construction interface; saved IDs and owner paths stay valid.
static func make() -> Node3D:
	return preload("res://scripts/utilities/energy_sword_visual.gd").make()
