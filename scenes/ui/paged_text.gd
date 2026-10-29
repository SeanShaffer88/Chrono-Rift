extends VBoxContainer
## Complete wrapped text, split at shaped line boundaries without discarding characters.
const Layout=preload("res://scripts/utilities/menu_layout.gd")
var text := "":
	set(value):
		text=value
		paginate()
var pages: Array[String]=[]
var page_index := 0
var body := Label.new()
var body_holder := Control.new()
var footer := HBoxContainer.new()
var previous := Button.new()
var next := Button.new()
var page_label := Label.new()
var available := Vector2(600,270)
var settings: Dictionary
func _ready() -> void:
	body.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_constant_override("line_spacing",0)
	body_holder.size_flags_vertical=Control.SIZE_EXPAND_FILL
	add_child(body_holder)
	body_holder.add_child(body)
	body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(footer)
	previous.text="Previous"
	next.text="Next"
	previous.pressed.connect(change_page.bind(-1))
	next.pressed.connect(change_page.bind(1))
	footer.add_child(previous)
	footer.add_child(page_label)
	footer.add_child(next)
	page_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	page_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	configure(available,Layout.metrics(get_viewport()))
func configure(area: Vector2,m: Dictionary) -> void:
	available=area
	settings=m
	add_theme_constant_override("separation",int(m.gap))
	body.add_theme_font_size_override("font_size",m.body)
	page_label.add_theme_font_size_override("font_size",m.body)
	Layout.button(previous,m)
	Layout.button(next,m)
	paginate()
func paginate() -> void:
	if not is_node_ready() or settings.is_empty(): return
	pages.clear()
	var paragraph := TextParagraph.new()
	paragraph.width=maxf(1,available.x)
	paragraph.break_flags=TextServer.BREAK_MANDATORY|TextServer.BREAK_WORD_BOUND|TextServer.BREAK_ADAPTIVE
	paragraph.add_string(text,ThemeDB.fallback_font,int(settings.body))
	var lines := maxi(1,floori((available.y-settings.touch-settings.gap-4)/ThemeDB.fallback_font.get_height(settings.body)))
	var start := 0
	for line in range(lines,paragraph.get_line_count(),lines):
		var boundary: int=paragraph.get_line_range(line).x
		pages.append(text.substr(start,boundary-start))
		start=boundary
	pages.append(text.substr(start))
	page_index=clampi(page_index,0,pages.size()-1)
	refresh()
func change_page(delta: int) -> void:
	page_index=clampi(page_index+delta,0,pages.size()-1)
	refresh()
func refresh() -> void:
	if pages.is_empty(): return
	body.text=pages[page_index]
	previous.disabled=page_index==0
	next.disabled=page_index==pages.size()-1
	page_label.text="%d / %d"%[page_index+1,pages.size()]
