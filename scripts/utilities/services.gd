extends RefCounted
## Null-safe access to autoloads. Bare autoload identifiers (e.g. `EventBus`) do
## not compile when a script runs under `godot -s`, so look them up by path instead:
##   const Services := preload("res://scripts/utilities/services.gd")
##   var bus := Services.event_bus()
##   if bus:
##       bus.player_damaged.emit(hp, max_hp)

static func event_bus() -> Node:
	return _autoload(^"EventBus")

static func game_state() -> Node:
	return _autoload(^"GameState")

static func _autoload(node_name: NodePath) -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null(node_name)
