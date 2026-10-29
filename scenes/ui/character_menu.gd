extends Control
## Shared pause overlay; bounded pages retain owned cards without scrolling.
const Services=preload("res://scripts/utilities/services.gd")
const Roster=preload("res://data/characters/character_roster.gd")
const Layout=preload("res://scripts/utilities/menu_layout.gd")
var hero: CharacterBody3D
var overlay := ColorRect.new()
var buttons: Dictionary={}
var launch := Button.new()
var was_paused := false
var opened := false
var panel := PanelContainer.new()
var card_grid := GridContainer.new()
var cards: Array[Control]=[]
var card_by_id: Dictionary={}
var labels: Dictionary={}
var available_ids: Array[String]=[]
var page_index := 0
var capacity := 4
var desired_panel_size := Vector2.ZERO
var panel_center := Vector2.ZERO
var previous := Button.new()
var next := Button.new()
var page_label := Label.new()
var close := Button.new()
var title := Label.new()
var note := Label.new()
var footer := Label.new()
var content := VBoxContainer.new()
var pager := HBoxContainer.new()
var info_button := Button.new()
var info := preload("res://scenes/ui/paged_text.gd").new()
var view_mode: StringName=&"roster"
var compact_footer := false
func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	launch.text="Characters"
	launch.pressed.connect(open_menu)
	add_child(launch)
	overlay.color=Color(0.02,0.05,0.09,0.86)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter=Control.MOUSE_FILTER_STOP
	add_child(overlay)
	var frame := StyleBoxFlat.new()
	frame.bg_color=Color("142432")
	frame.border_color=Color("aac6ce")
	frame.set_border_width_all(2)
	frame.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel",frame)
	overlay.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,16)
	panel.add_child(margin)
	margin.add_child(content)
	title.text="Characters"
	content.add_child(title)
	note.text="Switch in the dungeon or town. Position and health stay unchanged."
	note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	content.add_child(note)
	card_grid.name="CharacterCards"
	card_grid.size_flags_vertical=Control.SIZE_EXPAND_FILL
	content.add_child(card_grid)
	for id: String in Roster.HEROES:
		var column := VBoxContainer.new()
		column.name="Card_"+id
		column.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		card_grid.add_child(column)
		cards.append(column)
		card_by_id[id]=column
		var texts: Array[Label]=[]
		for value: String in [Roster.HEROES[id].name,Roster.HEROES[id].description,Roster.HEROES[id].starter.display_name if Roster.HEROES[id].starter!=null else "Weaponless · Swallow"]:
			var label := Label.new()
			label.text=value
			label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
			column.add_child(label)
			texts.append(label)
		labels[id]=texts
		var button := Button.new()
		_style_button(button)
		button.pressed.connect(select_character.bind(id))
		column.add_child(button)
		buttons[id]=button
	footer.text="Shared combat · Each weapon keeps its own durability"
	footer.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	content.add_child(footer)
	content.add_child(info)
	info.size_flags_vertical=Control.SIZE_EXPAND_FILL
	info.hide()
	previous.text="Previous"
	next.text="Next"
	_style_button(previous)
	_style_button(next)
	previous.pressed.connect(change_page.bind(-1))
	next.pressed.connect(change_page.bind(1))
	pager.add_child(previous)
	pager.add_child(page_label)
	pager.add_child(next)
	page_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	page_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(pager)
	close.name="CloseButton"
	close.text="Close"
	_style_button(close)
	close.pressed.connect(close_menu)
	content.add_child(close)
	info_button.text="Info"
	_style_button(info_button)
	info_button.pressed.connect(func(): set_view(&"info" if view_mode==&"roster" else &"roster"))
	pager.add_child(info_button)
	info_button.hide()
	overlay.hide()
	get_viewport().size_changed.connect(_layout_cards)
	_layout_cards.call_deferred()
func _layout_cards() -> void:
	if not is_node_ready(): return
	var focused_id := ""
	for id: String in buttons:
		if buttons[id].has_focus(): focused_id=id
	var safe := Layout.safe_rect(get_viewport())
	var m := Layout.metrics(get_viewport())
	compact_footer=OS.has_feature("android")
	if close.get_parent()!=(pager if compact_footer else content): close.reparent(pager if compact_footer else content)
	info_button.visible=compact_footer
	info_button.text="Info" if view_mode==&"roster" else "Roster"
	Layout.button(info_button,m)
	Layout.button(launch,m,true)
	launch.size=Vector2(maxf(180,launch.get_combined_minimum_size().x),m.primary)
	launch.position=Vector2(safe.get_center().x-launch.size.x/2,safe.position.y)
	content.add_theme_constant_override("separation",int(m.gap))
	title.add_theme_font_size_override("font_size",maxi(30,m.body+4))
	for label in [note,footer,page_label]: label.add_theme_font_size_override("font_size",m.secondary)
	Layout.button(previous,m)
	Layout.button(next,m)
	Layout.button(close,m,true)
	available_ids.clear()
	for id: String in Roster.HEROES:
		if Services.game_state().is_character_available(id): available_ids.append(id)
	card_grid.columns=3 if safe.size.x>=1440 and (safe.size.x-32-m.gap*2)/3>=360 else 2
	card_grid.add_theme_constant_override("h_separation",int(m.gap))
	card_grid.add_theme_constant_override("v_separation",int(m.gap))
	var panel_width: float=minf(safe.size.x,card_grid.columns*520+(card_grid.columns-1)*m.gap+36)
	var width: float = (panel_width-36-(card_grid.columns-1)*m.gap)/card_grid.columns
	var card_height := 0.0
	var card_heights: Dictionary={}
	for id: String in Roster.HEROES:
		var column: VBoxContainer=card_by_id[id]
		column.custom_minimum_size=Vector2(width,0)
		column.add_theme_constant_override("separation",int(m.gap))
		var sizes := [maxi(24,m.body+2),int(m.secondary),int(m.body)]
		var height: float=m.primary+3*m.gap
		for index in 3:
			var label: Label=labels[id][index]
			label.add_theme_font_size_override("font_size",sizes[index])
			label.visible=index!=2 or label.text!=labels[id][1].text
			if label.visible: height+=Layout.text_height(label.text,width,sizes[index])
			else: height-=m.gap
		card_height=maxf(card_height,height)
		card_heights[id]=height
		Layout.button(buttons[id],m,true)
	note.visible=not compact_footer
	footer.visible=not compact_footer
	var fixed: float = 40+5*m.gap+Layout.text_height(title.text,panel_width-36,maxi(30,m.body+4))+Layout.text_height(note.text,panel_width-36,m.secondary)+Layout.text_height(footer.text,panel_width-36,m.secondary)+m.touch+m.primary
	if compact_footer: fixed=40+2*m.gap+Layout.text_height(title.text,panel_width-36,maxi(30,m.body+4))+m.primary
	var rows := clampi(floori((safe.size.y-fixed+m.gap)/(card_height+m.gap)),1,2)
	rows=mini(rows,maxi(1,ceili(float(available_ids.size())/card_grid.columns)))
	capacity=card_grid.columns*rows
	if not focused_id.is_empty() and available_ids.has(focused_id): page_index=available_ids.find(focused_id)/capacity
	page_index=clampi(page_index,0,maxi(0,ceili(float(available_ids.size())/capacity)-1))
	var current_count := maxi(1,mini(capacity,available_ids.size()-page_index*capacity))
	card_grid.columns=mini(card_grid.columns,current_count)
	panel_width=card_grid.columns*width+(card_grid.columns-1)*m.gap+36
	rows=ceili(float(current_count)/card_grid.columns)
	card_height=0
	for index in range(page_index*capacity,mini(available_ids.size(),(page_index+1)*capacity)): card_height=maxf(card_height,card_heights[available_ids[index]])
	fixed=40+5*m.gap+Layout.text_height(title.text,panel_width-36,maxi(30,m.body+4))+Layout.text_height(note.text,panel_width-36,m.secondary)+Layout.text_height(footer.text,panel_width-36,m.secondary)+m.touch+m.primary
	if compact_footer:
		panel_width=maxf(panel_width,pager.get_combined_minimum_size().x+36)
		fixed=40+2*m.gap+Layout.text_height(title.text,panel_width-36,maxi(30,m.body+4))+m.primary
	refresh_page()
	desired_panel_size=Vector2(panel_width,minf(safe.size.y,fixed+rows*card_height+(rows-1)*m.gap))
	if view_mode==&"info":
		var paragraphs: Array[String]=[note.text,footer.text]
		for id: String in available_ids:
			paragraphs.append("%s: %s. %s"%[labels[id][0].text,labels[id][1].text,labels[id][2].text])
		info.text="\n\n".join(paragraphs)
		desired_panel_size=Vector2(minf(safe.size.x,maxf(780,pager.get_combined_minimum_size().x+36)),safe.size.y)
		info.configure(Vector2(desired_panel_size.x-36,safe.size.y-fixed+m.touch+m.gap),m)
		info.footer.hide()
		previous.disabled=info.page_index==0
		next.disabled=info.page_index==info.pages.size()-1
		page_label.text="%d / %d"%[info.page_index+1,info.pages.size()]
	card_grid.visible=view_mode==&"roster"
	info.visible=view_mode==&"info"
	panel_center=safe.get_center()
	_settle_panel.call_deferred()
func _settle_panel() -> void:
	panel.size=desired_panel_size
	panel.position=panel_center-panel.size/2
	var focus := get_viewport().gui_get_focus_owner()
	if opened and (focus==null or not panel.is_ancestor_of(focus)):
		if not next.disabled: next.grab_focus()
		else:
			for id: String in available_ids:
				if card_by_id[id].visible and not buttons[id].disabled:
					buttons[id].grab_focus()
					break
func change_page(delta: int) -> void:
	if view_mode==&"info":
		info.change_page(delta)
		_layout_cards()
		return
	page_index=clampi(page_index+delta,0,maxi(0,ceili(float(available_ids.size())/capacity)-1))
	_layout_cards()
func set_view(mode: StringName) -> void:
	if mode not in [&"roster",&"info"]: return
	view_mode=mode
	_layout_cards()
	info_button.grab_focus()
func set_page(index: int) -> void:
	change_page(index-(info.page_index if view_mode==&"info" else page_index))
func get_page_count() -> int:
	return info.pages.size() if view_mode==&"info" else maxi(1,ceili(float(available_ids.size())/capacity))
func refresh_page() -> void:
	var pages := maxi(1,ceili(float(available_ids.size())/capacity))
	page_index=clampi(page_index,0,pages-1)
	for id: String in Roster.HEROES:
		var index := available_ids.find(id)
		card_by_id[id].visible=index>=page_index*capacity and index<(page_index+1)*capacity
		buttons[id].disabled=id==Services.game_state().active_character_id
		buttons[id].text="Active" if buttons[id].disabled else "Switch"
	previous.disabled=page_index==0
	next.disabled=page_index==pages-1
	page_label.text="%d / %d"%[page_index+1,pages]

func _style_button(button: Button) -> void:
	for state_name in ["normal", "hover", "pressed", "disabled", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("203746") if state_name == "disabled" else Color("335868")
		style.border_color = Color("80abb8")
		style.set_border_width_all(2 if state_name in ["focus", "pressed"] else 1)
		style.set_corner_radius_all(4)
		button.add_theme_stylebox_override(state_name, style)


func open_menu() -> void:
	if opened or not is_instance_valid(hero) or hero.is_dead(): return
	was_paused=get_tree().paused
	for child: Node in get_parent().get_children():
		if child!=self and child.has_method("_release"): child._release()
	get_tree().paused=true
	opened=true
	get_parent().move_child(self,-1)
	launch.hide()
	view_mode=&"roster"
	_layout_cards()
	page_index=maxi(0,available_ids.find(Services.game_state().active_character_id))/capacity
	_layout_cards()
	overlay.show()

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
	launch.show()
	overlay.hide()

func _input(event: InputEvent) -> void:
	if opened and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if view_mode==&"info": set_view(&"roster")
		else: close_menu()
		get_viewport().set_input_as_handled()
	elif opened and (event is InputEventScreenTouch or event is InputEventScreenDrag):
		# GUI controls receive the event; sibling touch controls cannot attack/move.
		for child: Node in get_parent().get_children():
			if child != self and child.has_method("_release"):
				child._release()

func _exit_tree() -> void:
	if opened and get_tree():
		get_tree().paused = was_paused
