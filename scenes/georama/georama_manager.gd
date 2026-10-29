extends Node3D

signal closed
const Grid := preload("res://scenes/georama/town_grid.gd")
const Visuals := preload("res://scenes/georama/town_visuals.gd")
const Services := preload("res://scripts/utilities/services.gd")
const EnvironmentArt = preload("res://scenes/environment/environment_art.gd")
var grid := Grid.new()
var editing := true
var selected_id := ""
var pending_id := ""
var pending_cell := Vector2i(28, 30)
var pending_rotation := 0
var page := "assembly"
var foundation_ids: Array[String] = []
var component_ids: Array[String] = []
var touches: Dictionary = {}
var gesture := false
var _center := Vector2.ZERO
var _span := 0.0
var _angle := 0.0
var _pitch := 55.0
var _preview: Node3D
var _models: Dictionary = {}
var _residents: Dictionary = {}
var _ui: CanvasLayer
var _menu: PanelContainer
var _assembly: PanelContainer
var _foundations: ItemList
var _components: ItemList
var _slots: OptionButton
var _status: Label
var _dialog: PanelContainer
var _dialog_text: Label
var _joystick: Control
var _edit_button: Button
var _talk_button: Button
var _confirm: Button
var _rotate: Button
var _cancel: Button
var _camera_bar: HBoxContainer
var _dressing: MultiMeshInstance3D

func _ready() -> void:
	grid.bind_session(Services.game_state())
	grid.changed.connect(_refresh)
	Services.game_state().set_mode(1)
	_build_terrain()
	_build_ui()
	var characters := preload("res://scenes/ui/character_menu.gd").new()
	characters.hero = $MeleeHero
	_ui.add_child(characters)
	_refresh()
	set_editing(true)

func _build_terrain() -> void:
	EnvironmentArt.town_terrain(self)
	_dressing = preload("res://scenes/environment/town_dressing.gd").new()
	add_child(_dressing)
	var water := Visuals.box(self, Vector3(6, 0.03, 128), Vector3(50, 0.01, 63), Color(0.12, 0.56, 0.72))
	water.material_override = EnvironmentArt.river()
	$CameraPivot.position = Vector3(64, 0, 64)
	$MeleeHero.position = Vector3(62, 0.1, 70)
	$MeleeHero.camera_pivot.rotation.y = PI / 2
	$MeleeHero.face_direction(Vector3.LEFT)
	_update_camera()

func _panel(position_value: Vector2, size_value: Vector2) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.position = position_value
	panel.size = size_value
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.04, 0.095, 0.96)
	style.border_color = Color(0.7, 0.58, 0.32)
	style.set_border_width_all(2)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", style)
	_ui.add_child(panel)
	return panel

func _button(parent: Node, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(100, 40)
	button.add_theme_font_size_override("font_size", 18)
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _build_ui() -> void:
	_ui = CanvasLayer.new()
	add_child(_ui)
	_menu = _panel(Vector2(16, 16), Vector2(235, 205))
	var commands := VBoxContainer.new()
	_menu.add_child(commands)
	_button(commands, "Config / Assembly", show_page.bind("assembly"))
	_button(commands, "Move / Remove", show_page.bind("move"))
	_button(commands, "Georama Analysis", show_analysis)
	_button(commands, "Walking Mode", set_editing.bind(false))
	_assembly = _panel(Vector2(16, 235), Vector2(900, 330))
	var columns := HBoxContainer.new()
	_assembly.add_child(columns)
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 275
	columns.add_child(left)
	var label := Label.new()
	label.text = "Foundation Parts"
	left.add_child(label)
	_foundations = ItemList.new()
	_foundations.custom_minimum_size = Vector2(270, 240)
	_foundations.item_selected.connect(_select_foundation)
	left.add_child(_foundations)
	var middle := VBoxContainer.new()
	middle.custom_minimum_size.x = 275
	columns.add_child(middle)
	_slots = OptionButton.new()
	middle.add_child(_slots)
	_button(middle, "Attach specific part", attach_selected)
	_button(middle, "Remove specific part", detach_selected)
	_button(middle, "Arrange foundation", begin_selected)
	_button(middle, "Return to parts", remove_selected)
	var right := VBoxContainer.new()
	columns.add_child(right)
	label = Label.new()
	label.text = "Specific Parts"
	right.add_child(label)
	_components = ItemList.new()
	_components.custom_minimum_size = Vector2(275, 240)
	right.add_child(_components)
	var bar := HBoxContainer.new()
	_camera_bar = bar
	bar.position = Vector2(16, 650)
	_ui.add_child(bar)
	_confirm = _button(bar, "Confirm", confirm_placement)
	_rotate = _button(bar, "Rotate", rotate_pending)
	_cancel = _button(bar, "Back", cancel_placement)
	_button(bar, "View left", orbit.bind(-15.0))
	_button(bar, "View right", orbit.bind(15.0))
	_button(bar, "Tilt up", tilt.bind(10.0))
	_button(bar, "Tilt down", tilt.bind(-10.0))
	_status = Label.new()
	_status.position = Vector2(20, 595)
	_status.size = Vector2(950, 50)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_status)
	var top := VBoxContainer.new()
	top.position = Vector2(990, 16)
	_ui.add_child(top)
	_edit_button = _button(top, "Georama", set_editing.bind(true))
	_button(top, "Return to dungeon", request_close)
	_talk_button = _button(top, "Talk / Inspect", talk_nearest)
	_joystick = load("res://scenes/ui/virtual_joystick.tscn").instantiate()
	_ui.add_child(_joystick)
	_dialog = _panel(Vector2(290, 150), Vector2(700, 380))
	var dialogue := VBoxContainer.new()
	_dialog.add_child(dialogue)
	_dialog_text = Label.new()
	_dialog_text.custom_minimum_size = Vector2(660, 270)
	_dialog_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialogue.add_child(_dialog_text)
	_button(dialogue, "Back", _dialog.hide)
	_dialog.hide()

func _refresh() -> void:
	_dressing.cover(grid)
	_render_town()
	_foundations.clear()
	foundation_ids.clear()
	for id: String in grid.state.town_objects:
		var record: Dictionary = grid.state.town_objects[id]
		if page == "move" and not record.placed:
			continue
		foundation_ids.append(id)
		var event := "  Event" if grid.resident_active(id) and not record.event_seen else ""
		_foundations.add_item(grid.catalog[record.piece_id].display_name + (" [placed]" if record.placed else "") + event)
		if id == selected_id:
			_foundations.select(foundation_ids.size() - 1)
	_components.clear()
	component_ids = grid.available_components()
	for id in component_ids:
		_components.add_item(str(grid.state.collected_orb_ids[id]).replace("_", " ").capitalize())
	_refresh_slots()
	_status.text = "Recover foundation and specific parts in the dungeon." if foundation_ids.is_empty() else "Select a foundation. Assemble its recovered parts or arrange it in the world."

func _refresh_slots() -> void:
	_slots.clear()
	if not grid.state.town_objects.has(selected_id):
		return
	var record: Dictionary = grid.state.town_objects[selected_id]
	for slot: String in grid.catalog[record.piece_id].slots:
		_slots.add_item(slot + (": fitted" if record.components.has(slot) else ": ?"))
	if _slots.item_count > 0:
		_slots.select(0)

func _select_foundation(index: int) -> void:
	selected_id = foundation_ids[index]
	_refresh_slots()
	if page == "move":
		begin_selected()

func attach_selected() -> void:
	var selection := _components.get_selected_items()
	if _slots.selected < 0 or selection.is_empty() or not grid.state.town_objects.has(selected_id):
		_status.text = "Select a foundation slot and a specific part."
		return
	var record: Dictionary = grid.state.town_objects[selected_id]
	var slot: String = grid.catalog[record.piece_id].slots.keys()[_slots.selected]
	_status.text = "Part fitted." if grid.assemble(selected_id, slot, component_ids[selection[0]]) else "That part does not fit, or this structure is complete."

func detach_selected() -> void:
	if _slots.selected < 0 or not grid.state.town_objects.has(selected_id):
		return
	var slot: String = grid.catalog[grid.state.town_objects[selected_id].piece_id].slots.keys()[_slots.selected]
	_status.text = "Part returned." if grid.detach_component(selected_id, slot) else "Completed structures cannot be disassembled."

func show_page(value: String) -> void:
	set_editing(true)
	page = value
	_assembly.show()
	_refresh()

func begin_selected() -> void:
	if not grid.state.town_objects.has(selected_id):
		_status.text = "Recover and select a foundation first."
		return
	pending_id = selected_id
	var record: Dictionary = grid.state.town_objects[pending_id]
	pending_cell = record.cell if record.placed else Vector2i(28, 30)
	pending_rotation = record.rotation
	_assembly.hide()
	get_viewport().gui_release_focus()
	_render_town()
	_update_preview()

func rotate_pending() -> void:
	if not pending_id.is_empty():
		pending_rotation = (pending_rotation + 1) % 4
		_update_preview()

func confirm_placement() -> void:
	if pending_id.is_empty():
		return
	var error := grid.placement_error(pending_id, pending_cell, pending_rotation)
	if not error.is_empty():
		_status.text = error
		return
	var id := pending_id
	pending_id = ""
	grid.place(id, pending_cell, pending_rotation)
	_update_preview()

func cancel_placement() -> void:
	var had_preview := not pending_id.is_empty()
	pending_id = ""
	_update_preview()
	if had_preview:
		_render_town()

func remove_selected() -> void:
	if grid.remove(selected_id):
		cancel_placement()

func _update_preview() -> void:
	if is_instance_valid(_preview):
		_preview.free()
	_preview = null
	_confirm.disabled = pending_id.is_empty()
	_rotate.disabled = pending_id.is_empty()
	if pending_id.is_empty():
		return
	var record: Dictionary = grid.state.town_objects[pending_id]
	var piece: Resource = grid.catalog[record.piece_id]
	_preview = Visuals.make(piece, record, true)
	_position_model(_preview, piece, pending_cell, pending_rotation)
	add_child(_preview)
	var error := grid.placement_error(pending_id, pending_cell, pending_rotation)
	_confirm.disabled = not error.is_empty()
	_status.text = "Confirm placement. Rotate changes facing; Back restores the original location." if error.is_empty() else error
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.15, 0.8, 1, 0.5) if error.is_empty() else Color(1, 0.25, 0.2, 0.5)
	for child in _preview.find_children("*", "MeshInstance3D", true, false):
		child.material_override = material

func _position_model(model: Node3D, piece: Resource, cell: Vector2i, rotation_value: int) -> void:
	var dimensions: Vector2i = piece.dimensions
	if rotation_value % 2 != 0:
		dimensions = Vector2i(dimensions.y, dimensions.x)
	model.position = Vector3(cell.x * 2 + dimensions.x - 1, 0, cell.y * 2 + dimensions.y - 1)
	model.rotation.y = -rotation_value * PI / 2

func _render_town() -> void:
	for model: Node3D in _models.values():
		model.free()
	for resident: Node3D in _residents.values():
		resident.free()
	_models.clear()
	_residents.clear()
	for id: String in grid.state.town_objects:
		var record: Dictionary = grid.state.town_objects[id]
		if not record.placed or id == pending_id:
			continue
		var piece: Resource = grid.catalog[record.piece_id]
		var model := Visuals.make(piece, record)
		_position_model(model, piece, record.cell, record.rotation)
		add_child(model)
		_models[id] = model
		if grid.resident_active(id):
			var resident := Visuals.resident(piece.resident_name)
			add_child(resident)
			resident.position = model.to_global(Vector3(0, 0, -piece.dimensions.y - 1.3))
			_residents[id] = resident

func set_editing(value: bool) -> void:
	editing = value
	touches.clear()
	gesture = false
	if not value and not pending_id.is_empty():
		cancel_placement()
	_menu.visible = value
	_assembly.visible = value
	_camera_bar.visible = value
	_status.visible = value
	_dialog.hide()
	_joystick.visible = not value
	_talk_button.visible = not value
	_edit_button.visible = not value
	_confirm.visible = value
	_rotate.visible = value
	_cancel.visible = value
	$MeleeHero.process_mode = Node.PROCESS_MODE_DISABLED if value else Node.PROCESS_MODE_INHERIT
	if value:
		$CameraPivot/Camera3D.make_current()
	else:
		$MeleeHero.camera.make_current()

func talk_nearest() -> void:
	var nearest := ""
	var distance := 4.0
	for id: String in _residents:
		var next: float = $MeleeHero.global_position.distance_to(_residents[id].global_position)
		if next < distance:
			distance = next
			nearest = id
	_dialog_text.text = grid.talk(nearest) if not nearest.is_empty() else "Walk closer to a restored resident to talk."
	_dialog.show()

func show_analysis() -> void:
	var progress := grid.analysis()
	_dialog_text.text = "GEORAMA ANALYSIS\nCollection: %.0f%%\nComplete: %.0f%%\nRequest: %.0f%%" % [progress.collection, progress.complete, progress.request]
	for id: String in grid.state.town_objects:
		var record: Dictionary = grid.state.town_objects[id]
		var piece: Resource = grid.catalog[record.piece_id]
		if not piece.preferences.is_empty():
			_dialog_text.text += "\n" + piece.display_name
			if record.requests_known:
				var results := grid.request_results(id)
				for index in piece.preferences.size():
					_dialog_text.text += "\n" + ("Met: " if results[index] else "Unmet: ") + str(piece.preferences[index].text)
			else:
				_dialog_text.text += ": ? Speak to the resident."
	_dialog.show()

func _process(_delta: float) -> void:
	if not editing:
		$MeleeHero.set_physics_process(not _dialog.visible)
	for model: Node3D in _models.values():
		var local: Vector3 = model.to_local($MeleeHero.global_position)
		var roof := model.get_node_or_null("Roof")
		if roof:
			roof.visible = editing or absf(local.x) > 2.8 or absf(local.z) > 2.8
		var door := model.get_node_or_null("Door")
		if door:
			var open: bool = not editing and door.get_meta("ready") and door.global_position.distance_to($MeleeHero.global_position) < 3.0
			var collision: CollisionShape3D = door.get_node("Collision")
			if collision.disabled != open:
				collision.set_deferred("disabled", open)
			var leaf := door.get_node_or_null("Leaf")
			if leaf:
				leaf.visible = not open

func orbit(degrees: float) -> void:
	$CameraPivot.rotation.y += deg_to_rad(degrees)

func tilt(degrees: float) -> void:
	_pitch = clampf(_pitch + degrees, 25, 85)
	_update_camera()

func _update_camera() -> void:
	$CameraPivot/Camera3D.position = Vector3(0, sin(deg_to_rad(_pitch)) * 80, cos(deg_to_rad(_pitch)) * 80)
	$CameraPivot/Camera3D.rotation.x = -deg_to_rad(_pitch)

func ground_point(position_value: Vector2) -> Variant:
	var camera: Camera3D = $CameraPivot/Camera3D
	return Plane(Vector3.UP, 0).intersects_ray(camera.project_ray_origin(position_value), camera.project_ray_normal(position_value))

func _aim(position_value: Vector2) -> void:
	var point: Variant = ground_point(position_value)
	if point != null and not pending_id.is_empty():
		pending_cell = Vector2i(floori((point.x + 1) / 2), floori((point.z + 1) / 2))
		_update_preview()

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and (not event.pressed or event.canceled) and touches.has(event.index):
		touches.erase(event.index)
		if touches.is_empty():
			gesture = false
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if not editing:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_R: rotate_pending()
			KEY_ENTER: confirm_placement()
			KEY_ESCAPE: cancel_placement()
			KEY_Q: orbit(-15)
			KEY_E: orbit(15)
			KEY_Z: tilt(10)
			KEY_X: tilt(-10)
	if not pending_id.is_empty():
		var step := Vector2i.ZERO
		if event.is_action_pressed(&"ui_left"): step.x = -1
		if event.is_action_pressed(&"ui_right"): step.x = 1
		if event.is_action_pressed(&"ui_up"): step.y = -1
		if event.is_action_pressed(&"ui_down"): step.y = 1
		if step != Vector2i.ZERO:
			pending_cell += step
			_update_preview()
	if event is InputEventScreenTouch and event.pressed and not event.canceled:
		touches[event.index] = event.position
		if touches.size() == 1:
			_aim(event.position)
		elif touches.size() == 2:
			gesture = true
			var points: Array = touches.values()
			_center = (points[0] + points[1]) / 2
			_span = points[0].distance_to(points[1])
			_angle = (points[1] - points[0]).angle()
	elif event is InputEventScreenDrag and touches.has(event.index):
		touches[event.index] = event.position
		if touches.size() == 2:
			var points: Array = touches.values()
			var center: Vector2 = (points[0] + points[1]) / 2
			var span: float = points[0].distance_to(points[1])
			var angle: float = (points[1] - points[0]).angle()
			var from: Variant = ground_point(_center)
			var to: Variant = ground_point(center)
			if from != null and to != null:
				$CameraPivot.position += from - to
			if _span > 1 and span > 1:
				$CameraPivot/Camera3D.size = clampf($CameraPivot/Camera3D.size * _span / span, 18, 110)
			$CameraPivot.rotation.y -= angle_difference(_angle, angle)
			_center = center
			_span = span
			_angle = angle
		elif touches.size() >= 3:
			tilt(-event.relative.y * 0.1)
		elif not gesture:
			_aim(event.position)
	elif event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_aim(event.position)
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			$CameraPivot/Camera3D.size = clampf($CameraPivot/Camera3D.size + (-3 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 3), 18, 110)

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED]:
		touches.clear()
		gesture = false

func request_close() -> void:
	cancel_placement()
	closed.emit()
