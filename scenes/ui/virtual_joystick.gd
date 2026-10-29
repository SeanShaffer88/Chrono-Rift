extends Control
## Floating multi-touch thumbstick. A touch in the left part of the screen spawns the
## stick under the finger; releasing returns it to a rest anchor relative to the viewport.

signal joystick_moved(value: Vector2)
signal joystick_released

## Rest position as a fraction of the viewport size, so it scales across aspect ratios.
@export var rest_anchor: Vector2 = Vector2(0.2, 0.7)
@export_range(0.0, 0.9) var deadzone: float = 0.2
@export var radius: float = 90.0
@export var knob_radius: float = 38.0
## Fraction of the viewport width (from the left) that accepts joystick touches.
@export_range(0.1, 1.0) var touch_zone_width: float = 0.45
@export var base_color: Color = Color(1.0, 1.0, 1.0, 0.18)
@export var knob_color: Color = Color(1.0, 1.0, 1.0, 0.45)

var _touch_index := -1
var _base_pos := Vector2.ZERO
var _knob_pos := Vector2.ZERO
var _value := Vector2.ZERO

func _ready() -> void:
	add_to_group(&"virtual_joystick")
	mouse_filter = MOUSE_FILTER_IGNORE
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	_reset_to_rest()

## Normalized stick vector: length 0..1, zero inside the deadzone.
func get_vector() -> Vector2:
	return _value

func is_active() -> bool:
	return _touch_index != -1

func get_rest_position() -> Vector2:
	return get_viewport_rect().size * rest_anchor

## Maps a finger offset from the stick centre to a stick vector, rescaling past the deadzone.
static func compute_vector(offset: Vector2, stick_radius: float, dead: float) -> Vector2:
	if stick_radius <= 0.0:
		return Vector2.ZERO
	var amount := offset.length() / stick_radius
	if amount <= dead:
		return Vector2.ZERO
	var scaled := clampf((amount - dead) / (1.0 - dead), 0.0, 1.0)
	return offset.normalized() * scaled

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_handle_touch(event)
	elif event is InputEventScreenDrag:
		_handle_drag(event)

func _handle_touch(event: InputEventScreenTouch) -> void:
	if event.canceled:
		if event.index == _touch_index:
			_release()
		return
	if event.pressed:
		if not is_visible_in_tree() or _touch_index != -1 or not _in_touch_zone(event.position):
			return
		_touch_index = event.index
		_base_pos = event.position
		_update_knob(event.position)
		_accept_event()
	elif event.index == _touch_index:
		_release()
		_accept_event()

func _release() -> void:
	_touch_index = -1
	_reset_to_rest()
	joystick_released.emit()

func _notification(what: int) -> void:
	if what in [NOTIFICATION_EXIT_TREE, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_WINDOW_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED] and is_active():
		_release()
	elif what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree() and is_active():
		_release()

func _handle_drag(event: InputEventScreenDrag) -> void:
	if event.index != _touch_index:
		return
	_update_knob(event.position)
	_accept_event()

func _update_knob(touch_pos: Vector2) -> void:
	var offset := touch_pos - _base_pos
	# Floating stick: drag the base along when the finger leaves the ring.
	if offset.length() > radius:
		_base_pos = touch_pos - offset.normalized() * radius
		offset = touch_pos - _base_pos
	_knob_pos = _base_pos + offset
	_set_value(compute_vector(offset, radius, deadzone))
	queue_redraw()

func _set_value(value: Vector2) -> void:
	if value == _value:
		return
	_value = value
	joystick_moved.emit(_value)

func _reset_to_rest() -> void:
	_base_pos = get_rest_position()
	_knob_pos = _base_pos
	_set_value(Vector2.ZERO)
	queue_redraw()

func _in_touch_zone(pos: Vector2) -> bool:
	return pos.x <= get_viewport_rect().size.x * touch_zone_width

func _accept_event() -> void:
	if is_inside_tree():
		get_viewport().set_input_as_handled()

func _on_viewport_size_changed() -> void:
	if not is_active():
		_reset_to_rest()

func _draw() -> void:
	var origin := get_global_position()
	draw_circle(_base_pos - origin, radius, base_color)
	draw_arc(_base_pos - origin, radius, 0.0, TAU, 48, knob_color, 2.0)
	draw_circle(_knob_pos - origin, knob_radius, knob_color)
