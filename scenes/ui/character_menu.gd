extends Control
## Shared pause overlay used in both dungeon and town viewports.
const Services = preload("res://scripts/utilities/services.gd")
const Roster = preload("res://data/characters/character_roster.gd")
var hero: CharacterBody3D
var overlay := ColorRect.new()
var buttons: Dictionary = {}
var launch := Button.new()
var was_paused := false
var opened := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	launch.text = "Characters"
	launch.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	launch.position = Vector2(-90, 16)
	launch.custom_minimum_size = Vector2(180, 44)
	launch.pressed.connect(open_menu)
	add_child(launch)
	overlay.color = Color(0.02, 0.05, 0.09, 0.86)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(980, 420)
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color("142432")
	frame.border_color = Color("aac6ce")
	frame.set_border_width_all(2)
	frame.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", frame)
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	panel.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 18)
	margin.add_child(content)
	var title := Label.new()
	title.text = "Characters"
	title.add_theme_font_size_override("font_size", 30)
	content.add_child(title)
	var note := Label.new()
	note.text = "Switch in the dungeon or town. Position and health stay unchanged."
	content.add_child(note)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	content.add_child(row)
	for id: String in Roster.HEROES:
		var column := VBoxContainer.new()
		column.custom_minimum_size = Vector2(295, 190)
		column.add_theme_constant_override("separation", 18)
		row.add_child(column)
		var name_label := Label.new()
		name_label.text = Roster.HEROES[id].name
		name_label.add_theme_font_size_override("font_size", 24)
		column.add_child(name_label)
		var description := Label.new()
		description.text = Roster.HEROES[id].description
		column.add_child(description)
		var weapon := Label.new()
		weapon.text = Roster.HEROES[id].starter.display_name
		column.add_child(weapon)
		var button := Button.new()
		button.custom_minimum_size.y = 52
		_style_button(button)
		button.pressed.connect(select_character.bind(id))
		column.add_child(button)
		buttons[id] = button
	var footer := Label.new()
	footer.text = "Shared combat · Each character keeps their own weapon durability"
	content.add_child(footer)
	var close := Button.new()
	close.text = "Close"
	close.custom_minimum_size.y = 48
	_style_button(close)
	close.pressed.connect(close_menu)
	content.add_child(close)
	overlay.hide()

func _style_button(button: Button) -> void:
	for state_name in ["normal", "hover", "pressed", "disabled", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("203746") if state_name == "disabled" else Color("335868")
		style.border_color = Color("80abb8")
		style.set_border_width_all(2 if state_name in ["focus", "pressed"] else 1)
		style.set_corner_radius_all(4)
		button.add_theme_stylebox_override(state_name, style)

func open_menu() -> void:
	if opened or not is_instance_valid(hero) or hero.is_dead():
		return
	was_paused = get_tree().paused
	for child: Node in get_parent().get_children():
		if child != self and child.has_method("_release"):
			child._release()
	get_tree().paused = true
	opened = true
	overlay.show()
	for id: String in buttons:
		var active: bool = id == Services.game_state().active_character_id
		buttons[id].text = "Active" if active else "Switch"
		buttons[id].disabled = active

func select_character(id: String) -> bool:
	if not opened or not is_instance_valid(hero) or hero.is_dead():
		return false
	if not Services.game_state().swap_character(id):
		return false
	close_menu()
	return true

func close_menu() -> void:
	if not opened:
		return
	get_tree().paused = was_paused
	opened = false
	overlay.hide()

func _input(event: InputEvent) -> void:
	if opened and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		close_menu()
		get_viewport().set_input_as_handled()
	elif opened and (event is InputEventScreenTouch or event is InputEventScreenDrag):
		# GUI controls receive the event; sibling touch controls cannot attack/move.
		for child: Node in get_parent().get_children():
			if child != self and child.has_method("_release"):
				child._release()

func _exit_tree() -> void:
	if opened and get_tree():
		get_tree().paused = was_paused
