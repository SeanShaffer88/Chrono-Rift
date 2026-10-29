extends Control
## Bounded noninteractive word titles, owned by the dungeon HUD.
signal started(event_key: StringName)
signal finished(event_key: StringName)
@export var animate_titles := true
const Layout=preload("res://scripts/utilities/menu_layout.gd")
var active: Dictionary={}
var pending: Dictionary={}
var words: Array[Label]=[]
var fallback := Label.new()
var bases: Array[Vector2]=[]
var reveal: Tween
var lifetime: Tween
var generation := 0
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	for index in 8:
		var label := Label.new()
		label.mouse_filter=Control.MOUSE_FILTER_IGNORE
		label.add_theme_color_override("font_color",Color("eadfc8"))
		add_child(label)
		words.append(label)
		bases.append(Vector2.ZERO)
	fallback.mouse_filter=Control.MOUSE_FILTER_IGNORE
	fallback.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	fallback.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	fallback.add_theme_color_override("font_color",Color("eadfc8"))
	add_child(fallback)
	get_viewport().size_changed.connect(_resize_title)
	hide()
func show_title(kind: StringName,text: String,event_key: StringName,immediate: bool=false) -> void:
	if text.strip_edges().is_empty(): return
	if active.get("key")==event_key or pending.get("key")==event_key: return
	var item := {"kind":kind,"text":text,"key":event_key,"immediate":immediate}
	if active.is_empty():
		_begin(item)
	elif kind==&"unlock" and active.kind==&"biome":
		cancel()
		_begin(item)
	elif pending.is_empty() or kind==&"unlock" or pending.kind==&"biome":
		pending=item
func _begin(item: Dictionary) -> void:
	active=item
	generation+=1
	var token := generation
	modulate=Color.WHITE
	show()
	_layout_words()
	var visible_labels: Array[Label]=[]
	for label in words:
		if label.visible: visible_labels.append(label)
	if fallback.visible: visible_labels.append(fallback)
	var animated := animate_titles and not bool(item.immediate)
	var duration := 0.0
	if animated:
		reveal=create_tween().set_parallel(true)
		for index in visible_labels.size():
			var label := visible_labels[index]
			var at := label.position
			label.modulate.a=0
			label.position.y+=8
			reveal.tween_property(label,"modulate:a",1.0,0.24).set_delay(index*0.045)
			reveal.tween_property(label,"position:y",at.y,0.24).set_delay(index*0.045)
		duration=0.24+maxi(0,visible_labels.size()-1)*0.045
	lifetime=create_tween()
	if animated:
		lifetime.tween_interval(duration+1.0)
		lifetime.tween_property(self,"modulate:a",0.0,0.18)
	else:
		lifetime.tween_interval(1.18)
	lifetime.tween_callback(_complete.bind(token))
	started.emit(item.key)
func _layout_words() -> void:
	if active.is_empty(): return
	var safe := Layout.safe_rect(get_viewport())
	var metrics := Layout.metrics(get_viewport())
	var font_size := maxi(32,int(metrics.body)+8)
	var pieces: PackedStringArray=String(active.text).split(" ",false)
	var font := ThemeDB.fallback_font
	var space := font.get_string_size(" ",HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
	var total := 0.0
	for piece in pieces: total+=font.get_string_size(piece,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
	total+=maxi(0,pieces.size()-1)*space
	var use_fallback := pieces.size()>8 or total>safe.size.x
	for index in words.size():
		words[index].visible=not use_fallback and index<pieces.size()
		words[index].modulate=Color.WHITE
	fallback.visible=use_fallback
	fallback.modulate=Color.WHITE
	var y: float=safe.position.y+metrics.primary+metrics.gap
	if use_fallback:
		fallback.text=active.text
		fallback.add_theme_font_size_override("font_size",font_size)
		fallback.position=Vector2(safe.position.x,y)
		fallback.size=Vector2(safe.size.x,Layout.text_height(active.text,safe.size.x,font_size))
	else:
		var x := safe.get_center().x-total/2
		for index in pieces.size():
			var label := words[index]
			label.text=pieces[index]
			label.add_theme_font_size_override("font_size",font_size)
			bases[index]=Vector2(x,y)
			label.position=bases[index]
			x+=font.get_string_size(pieces[index],HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x+space
func finish_reveal() -> void:
	if reveal!=null and reveal.is_valid(): reveal.kill()
	for index in words.size():
		words[index].modulate=Color.WHITE
		words[index].position=bases[index]
	fallback.modulate=Color.WHITE
func _resize_title() -> void:
	if active.is_empty(): return
	finish_reveal()
	_layout_words()
func _complete(token: int) -> void:
	if token!=generation or active.is_empty(): return
	var key: StringName=active.key
	var item := pending
	active={}
	pending={}
	hide()
	finished.emit(key)
	if token==generation and not item.is_empty(): _begin(item)
func cancel() -> void:
	generation+=1
	if reveal!=null and reveal.is_valid(): reveal.kill()
	if lifetime!=null and lifetime.is_valid(): lifetime.kill()
	active={}
	pending={}
	hide()
func _exit_tree() -> void:
	cancel()
