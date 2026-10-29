extends Node3D

const Floor := preload("res://scenes/dungeon/floor_generator.gd")
@export var dungeon_seed: int = 1337
var floor_number := 1
var floor_generator := Floor.new()
var town_view: Node3D = null
var _town_layer: CanvasLayer
var _previous_process_mode: int

func _ready() -> void:
	add_child(floor_generator)
	floor_generator.exit_reached.connect(_queue_next_floor)
	_load_floor()
	var button := Button.new()
	button.text = "Town / Georama"
	button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	button.offset_left = -230
	button.offset_top = 16
	button.offset_right = -16
	button.offset_bottom = 64
	button.pressed.connect(open_town)
	$TouchUI.add_child(button)

func open_town() -> void:
	if is_instance_valid(town_view) or $MeleeHero.is_dead():
		return
	_previous_process_mode = process_mode
	$TouchUI.hide()
	hide()
	process_mode = Node.PROCESS_MODE_DISABLED
	_town_layer = CanvasLayer.new()
	_town_layer.layer = 20
	var container := SubViewportContainer.new()
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.stretch = true
	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(viewport)
	_town_layer.add_child(container)
	get_tree().root.add_child(_town_layer)
	town_view = load("res://scenes/georama/georama_manager.tscn").instantiate()
	town_view.closed.connect(close_town)
	viewport.add_child(town_view)

func close_town() -> void:
	if not is_instance_valid(town_view):
		return
	_town_layer.queue_free()
	town_view = null
	process_mode = _previous_process_mode
	show()
	$TouchUI.show()
	preload("res://scripts/utilities/services.gd").game_state().set_mode(0)

func _exit_tree() -> void:
	if is_instance_valid(_town_layer):
		_town_layer.queue_free()

func _load_floor() -> void:
	if not floor_generator.generate(dungeon_seed + (floor_number - 1) * 1009, floor_number):
		push_error("Dungeon generation failed for seed %d, floor %d" % [dungeon_seed, floor_number])
		return
	$MeleeHero.position = floor_generator.cell_to_world(floor_generator.spawn_cell) + Vector3.UP * 0.1
	$MeleeHero.velocity = Vector3.ZERO

func _queue_next_floor() -> void:
	# Exit triggers run during physics; replace collision objects afterward.
	_advance_floor.call_deferred()

func _advance_floor() -> void:
	floor_number += 1
	_load_floor()
