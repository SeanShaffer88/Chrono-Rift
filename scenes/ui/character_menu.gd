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
var panel: PanelContainer
var card_scroll: ScrollContainer
var card_grid: GridContainer
var cards: Array[Control] = []

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
	panel = PanelContainer.new()
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color("142432")
	frame.border_color = Color("aac6ce")
	frame.set_border_width_all(2)
	frame.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", frame)
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	panel.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	margin.add_child(content)
	var title := Label.new()
	title.text = "Characters"
	title.add_theme_font_size_override("font_size", 30)
	content.add_child(title)
	var note := Label.new()
	note.text = "Switch in the dungeon or town. Position and health stay unchanged."
	note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	content.add_child(note)
	card_scroll=ScrollContainer.new()
	card_scroll.name="CardScroll"
	card_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	card_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	content.add_child(card_scroll)
	card_grid=GridContainer.new()
	card_grid.name="CharacterCards"
	card_grid.add_theme_constant_override("h_separation",16)
	card_grid.add_theme_constant_override("v_separation",16)
	card_grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	card_scroll.add_child(card_grid)
	for id: String in Roster.HEROES:
		var column := VBoxContainer.new()
		column.name="Card_"+id
		column.custom_minimum_size = Vector2(0,160)
		column.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		cards.append(column)
		column.add_theme_constant_override("separation", 12)
		card_grid.add_child(column)
		var name_label := Label.new()
		name_label.text = Roster.HEROES[id].name
		name_label.add_theme_font_size_override("font_size", 24)
		name_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		column.add_child(name_label)
		var description := Label.new()
		description.text = Roster.HEROES[id].description
		description.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		column.add_child(description)
		var weapon := Label.new()
		weapon.text = Roster.HEROES[id].starter.display_name if Roster.HEROES[id].starter != null else "Weaponless · Swallow"
		weapon.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		column.add_child(weapon)
		var button := Button.new()
		button.custom_minimum_size.y = 52
		_style_button(button)
		button.pressed.connect(select_character.bind(id))
		column.add_child(button)
		buttons[id] = button
	var footer := Label.new()
	footer.text = "Shared combat · Each character keeps their own weapon durability"
	footer.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	content.add_child(footer)
	var close := Button.new()
	close.name="CloseButton"
	close.text = "Close"
	close.custom_minimum_size.y = 48
	_style_button(close)
	close.pressed.connect(close_menu)
	content.add_child(close)
	overlay.hide()
	resized.connect(_layout_cards)
	_layout_cards.call_deferred()

func _layout_cards() -> void:
	if panel==null or card_grid==null: return
	var viewport_size := get_viewport_rect().size
	var width := maxf(240,minf(980,viewport_size.x-32))
	panel.custom_minimum_size=Vector2(width,maxf(240,minf(620,viewport_size.y-32)))
	card_grid.columns=2 if viewport_size.x>=680 else 1
	var card_width := (width-48-(card_grid.columns-1)*16)/card_grid.columns
	for card: Control in cards: card.custom_minimum_size.x=maxf(160,card_width)

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
		buttons[id].get_parent().visible=Services.game_state().is_character_available(id)
		var active: bool = id == Services.game_state().active_character_id
		buttons[id].text = "Active" if active else "Switch"
		buttons[id].disabled = active

func select_character(id: String) -> bool:
	if not opened or not is_instance_valid(hero) or hero.is_dead():
		return false
	if not Services.game_state().is_character_available(id) or not Services.game_state().swap_character(id):
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
