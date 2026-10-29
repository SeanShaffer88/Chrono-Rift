extends Control
## Local-only save details and explicit archive/fresh confirmation.
const Layout=preload("res://scripts/utilities/menu_layout.gd")
var session: Node
var status_label: Label
var launch := Button.new()
var overlay := ColorRect.new()
var panel := PanelContainer.new()
var column := VBoxContainer.new()
var heading := Label.new()
var notes := preload("res://scenes/ui/paged_text.gd").new()
var actions := HBoxContainer.new()
var cancel := Button.new()
var confirm := Button.new()
var opened := false
var was_paused := false
var desired_size := Vector2.ZERO
func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(launch)
	launch.pressed.connect(open_details)
	overlay.color=Color(0.02,0.05,0.09,0.86)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter=Control.MOUSE_FILTER_STOP
	add_child(overlay)
	overlay.add_child(panel)
	var frame := StyleBoxFlat.new()
	frame.bg_color=Color("142432")
	frame.border_color=Color("aac6ce")
	frame.set_border_width_all(2)
	frame.set_content_margin_all(16)
	frame.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel",frame)
	panel.add_child(column)
	heading.text="Save recovery"
	column.add_child(heading)
	notes.size_flags_vertical=Control.SIZE_EXPAND_FILL
	column.add_child(notes)
	column.add_child(actions)
	cancel.text="Cancel"
	confirm.text="Back up & start fresh"
	for control in [launch,cancel,confirm]:
		for state_name in ["normal","hover","pressed","focus","disabled"]:
			var style := StyleBoxFlat.new()
			style.bg_color=Color("335868") if state_name!="disabled" else Color("203746")
			style.border_color=Color("80abb8")
			style.set_border_width_all(2 if state_name=="focus" else 1)
			style.set_corner_radius_all(4)
			control.add_theme_stylebox_override(state_name,style)
	actions.add_child(cancel)
	actions.add_child(confirm)
	confirm.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	cancel.pressed.connect(close_details)
	confirm.pressed.connect(confirm_fresh)
	overlay.hide()
	session.status_changed.connect(func(_text: String): refresh())
	session.diagnostic_changed.connect(func(_data: Dictionary): refresh())
	get_viewport().size_changed.connect(refresh)
	refresh.call_deferred()
func refresh() -> void:
	if not is_node_ready(): return
	var safe := Layout.safe_rect(get_viewport())
	var m := Layout.metrics(get_viewport())
	status_label.text=session.display_status()
	status_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_font_size_override("font_size",m.secondary)
	launch.visible=not opened and session.diagnostic.get("reason","none") not in ["none","missing"]
	launch.text="Recovery" if session.can_start_fresh() else "Details"
	Layout.button(launch,m,true)
	var launch_width := maxf(m.touch,launch.get_combined_minimum_size().x)
	var width := minf(safe.size.x-launch_width-m.gap,maxf(260,ThemeDB.fallback_font.get_string_size(status_label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,m.secondary).x))
	status_label.size=Vector2(width,maxf(m.primary if launch.visible else 0,Layout.text_height(status_label.text,width,m.secondary)))
	launch.size=Vector2(launch_width,m.primary)
	launch.position=Vector2(safe.end.x-launch_width,safe.position.y+m.primary+m.gap)
	for control in [cancel,confirm]: Layout.button(control,m,true)
	column.add_theme_constant_override("separation",int(m.gap))
	actions.add_theme_constant_override("separation",int(m.gap))
	heading.add_theme_font_size_override("font_size",maxi(30,m.body+4))
	var width_available := minf(1000,safe.size.x)
	var fixed: float=32+ThemeDB.fallback_font.get_height(maxi(30,m.body+4))+m.primary+2*m.gap
	var shaped := TextParagraph.new()
	shaped.width=width_available-32
	shaped.break_flags=TextServer.BREAK_MANDATORY|TextServer.BREAK_WORD_BOUND|TextServer.BREAK_ADAPTIVE
	shaped.add_string(notes.text,ThemeDB.fallback_font,int(m.body))
	var natural: float=fixed+shaped.get_line_count()*ThemeDB.fallback_font.get_height(m.body)+5
	desired_size=Vector2(width_available,minf(minf(safe.size.y,650 if OS.has_feature("android") else 480),natural))
	var block: float=desired_size.y-fixed
	notes.configure(Vector2(desired_size.x-32,block+m.touch+m.gap),m)
	if notes.pages.size()>1: notes.configure(Vector2(desired_size.x-32,block),m)
	notes.footer.visible=notes.pages.size()>1
	settle_panel.call_deferred()
func settle_panel() -> void:
	panel.size=desired_size
	panel.position=Layout.safe_rect(get_viewport()).get_center()-panel.size/2
func open_details() -> void:
	if opened: return
	was_paused=get_tree().paused
	get_tree().paused=true
	for joystick: Node in get_tree().get_nodes_in_group("virtual_joystick"):
		if joystick.has_method("_release"): joystick._release()
	for control: Node in get_parent().get_children():
		if control.has_method("_release"): control._release()
	get_parent().move_child(self,-1)
	opened=true
	heading.text="Save recovery" if session.can_start_fresh() else "Save details"
	notes.text=session.details()
	if session.can_start_fresh(): notes.text=session.display_status()+"\n\nBack up existing files, then start fresh. A verified app-local backup is made first. Clearing app data or uninstalling can remove backups.\n\nDetails\n"+session.details(false)
	notes.page_index=0
	cancel.text="Cancel"
	confirm.visible=session.can_start_fresh()
	confirm.disabled=false
	overlay.show()
	refresh()
	cancel.grab_focus()
func confirm_fresh() -> void:
	if not opened or confirm.disabled or not session.can_start_fresh(): return
	confirm.disabled=true
	var result: Dictionary=session.start_fresh_with_backup()
	confirm.hide()
	cancel.text="Continue" if result.ok else "Close"
	heading.text="Fresh game saved" if result.ok else "Recovery did not complete"
	notes.text="A fresh game has been saved. Original files are retained in verified app-local storage." if result.ok else "Existing active files were preserved or restored." if result.rollback_ok else "Active save files may be incomplete. Saving is blocked; the archived files and recovery journal are retained for repair."
	if not result.archive_path.is_empty(): notes.text+="\n\n%s\n%s"%["Verified app-local backup:" if result.ok else "Local backup folder (may be incomplete):",result.archive_path]
	if not result.ok: notes.text+="\n\n"+session.details()
	notes.page_index=0
	refresh()
	cancel.grab_focus()
func close_details() -> void:
	if not opened: return
	get_tree().paused=was_paused
	opened=false
	overlay.hide()
	refresh()
func _input(event: InputEvent) -> void:
	if opened and event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:
		close_details()
		get_viewport().set_input_as_handled()
func _exit_tree() -> void:
	if opened: get_tree().paused=was_paused
