extends Control
## Round on-screen button that presses an input action while a finger is on it.
## Tracks its own touch index so it works alongside the joystick and other buttons.

@export var action: StringName = &"attack"
@export var label_text: String = "ATK"
@export var idle_color: Color = Color(1.0, 1.0, 1.0, 0.25)
@export var pressed_color: Color = Color(1.0, 0.85, 0.4, 0.55)
@export var font_size: int = 20

var _touch_index := -1

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE

func is_pressed() -> bool:
	return _touch_index != -1

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.canceled:
			if event.index == _touch_index:
				_release()
			return
		if event.pressed and is_visible_in_tree() and _touch_index == -1 and _contains(event.position):
			_touch_index = event.index
			Input.action_press(action)
			queue_redraw()
			get_viewport().set_input_as_handled()
		elif not event.pressed and event.index == _touch_index:
			_release()
			get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what in [NOTIFICATION_EXIT_TREE, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_WINDOW_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED] and is_pressed():
		_release()
	elif what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree() and is_pressed():
		_release()

func _release() -> void:
	_touch_index = -1
	Input.action_release(action)
	queue_redraw()

func _contains(pos: Vector2) -> bool:
	var rect := get_global_rect()
	var r := minf(rect.size.x, rect.size.y) * 0.5
	return pos.distance_to(rect.get_center()) <= r

func _draw() -> void:
	var r := minf(size.x, size.y) * 0.5
	draw_circle(size * 0.5, r, pressed_color if is_pressed() else idle_color)
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(0.0, size.y * 0.5 + font_size * 0.35), label_text, HORIZONTAL_ALIGNMENT_CENTER, size.x, font_size)
