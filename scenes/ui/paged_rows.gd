extends VBoxContainer
## Bounded reusable row buttons. Selection is an object ID, never a page-local index.
signal id_selected(id: String)
const Layout=preload("res://scripts/utilities/menu_layout.gd")
var entries: Array[Dictionary]=[]
var selected_id := ""
var page_index := 0
var capacity := 5
var rows := VBoxContainer.new()
var footer := HBoxContainer.new()
var previous := Button.new()
var next := Button.new()
var page_label := Label.new()
var row_buttons: Array[Button]=[]
var row_height := 44.0
var available_size := Vector2(275,240)
var settings: Dictionary
func _ready() -> void:
	add_child(rows)
	rows.size_flags_vertical=Control.SIZE_EXPAND_FILL
	add_child(footer)
	previous.text="Prev"
	next.text="Next"
	previous.pressed.connect(change_page.bind(-1))
	next.pressed.connect(change_page.bind(1))
	footer.add_child(previous)
	footer.add_child(page_label)
	footer.add_child(next)
	page_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	page_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	configure(Vector2(275,240),Layout.metrics(get_viewport()))
func set_entries(value: Array[Dictionary],selection: String="") -> void:
	entries=value
	selected_id=selection
	var found := false
	for entry: Dictionary in entries: found=found or entry.id==selected_id
	if not found: selected_id=""
	if is_node_ready() and not settings.is_empty(): configure(available_size,settings)
	else: refresh()
func configure(available: Vector2,m: Dictionary) -> void:
	var focus_id := ""
	for control: Button in row_buttons:
		if control.has_focus(): focus_id=str(control.get_meta("id",""))
	settings=m
	available_size=available
	add_theme_constant_override("separation",int(m.gap))
	rows.add_theme_constant_override("separation",0)
	Layout.button(previous,m)
	Layout.button(next,m)
	page_label.add_theme_font_size_override("font_size",m.body)
	row_height=m.touch
	for entry: Dictionary in entries: row_height=maxf(row_height,Layout.text_height(entry.label,available.x-24,m.body)+12)
	capacity=clampi(floori((available.y-m.touch-m.gap)/row_height),1,10)
	if not focus_id.is_empty():
		for index in entries.size():
			if entries[index].id==focus_id: page_index=index/capacity
	refresh()
	if not focus_id.is_empty():
		for control: Button in row_buttons:
			if control.visible and control.get_meta("id","")==focus_id: control.grab_focus()
func change_page(delta: int) -> void:
	page_index=clampi(page_index+delta,0,maxi(0,ceili(float(entries.size())/capacity)-1))
	refresh()
func choose(id: String) -> void:
	var valid := false
	for entry: Dictionary in entries: valid=valid or entry.id==id
	if not valid: return
	selected_id=id
	refresh()
	id_selected.emit(id)
func refresh() -> void:
	if not is_node_ready() or settings.is_empty(): return
	var count := maxi(1,ceili(float(entries.size())/capacity))
	page_index=clampi(page_index,0,count-1)
	while row_buttons.size()<capacity:
		var control := Button.new()
		control.toggle_mode=true
		control.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		var caption := Label.new()
		caption.name="Caption"
		caption.mouse_filter=Control.MOUSE_FILTER_IGNORE
		caption.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		caption.add_theme_constant_override("line_spacing",0)
		control.add_child(caption)
		caption.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		caption.offset_left=12
		caption.offset_right=-12
		caption.offset_top=6
		caption.offset_bottom=-6
		rows.add_child(control)
		row_buttons.append(control)
		control.pressed.connect(func(): choose(str(control.get_meta("id"))))
	for index in row_buttons.size():
		var control := row_buttons[index]
		var item := page_index*capacity+index
		control.visible=index<capacity and item<entries.size()
		if not control.visible: continue
		Layout.button(control,settings)
		control.custom_minimum_size=Vector2(settings.touch,row_height)
		control.text=""
		var caption: Label=control.get_node("Caption")
		caption.text=entries[item].label
		caption.add_theme_font_size_override("font_size",settings.body)
		control.set_meta("id",entries[item].id)
		control.set_pressed_no_signal(entries[item].id==selected_id)
	previous.disabled=page_index==0
	next.disabled=page_index==count-1
	page_label.text="%d / %d"%[page_index+1,count]
