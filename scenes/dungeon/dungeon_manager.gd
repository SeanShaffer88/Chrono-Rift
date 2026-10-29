extends Node3D

const Layout=preload("res://scripts/utilities/menu_layout.gd")
const MajorTitle=preload("res://scenes/ui/major_title.gd")
@export var animate_titles := true
var major_title: MajorTitle
var titles_ready := false
var last_announced_entry: StringName=&""
var _hud: Control
var _travel_button: Button
var _save_label: Label
var _defeat_title: Label
var _defeat_note: Label
var _defeat_note_holder: Control
var _retry: Button
var _defeat_size := Vector2.ZERO
const Services = preload("res://scripts/utilities/services.gd")
const Floor := preload("res://scenes/dungeon/floor_generator.gd")
@export var dungeon_seed: int = 1337
@export var persistence_path: String = "user://saves/autosave.json"
var floor_number := 1
var floor_generator := Floor.new()
var town_view: Node3D = null
var _town_layer: CanvasLayer
var _previous_process_mode: int
var _defeat_ui: PanelContainer
var save_session: Node

func _ready() -> void:
	add_child(floor_generator)
	floor_generator.exit_reached.connect(_queue_next_floor)
	_load_floor()
	var companion := preload("res://scenes/dungeon/collector_companion.gd").new()
	companion.hero = $MeleeHero
	add_child(companion)
	var hud := preload("res://scenes/ui/adventure_hud.gd").new()
	hud.hero = $MeleeHero
	_hud=hud
	$TouchUI.add_child(hud)
	major_title=MajorTitle.new()
	major_title.name="MajorTitle"
	major_title.animate_titles=animate_titles
	$TouchUI.add_child(major_title)
	Services.game_state().character_unlocked.connect(_on_character_unlocked)
	var characters := preload("res://scenes/ui/character_menu.gd").new()
	characters.hero = $MeleeHero
	$TouchUI.add_child(characters)
	var button := Button.new()
	button.text = "Town / Georama"
	_travel_button=button
	button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	button.offset_left = -230
	button.offset_top = 16
	button.offset_right = -16
	button.offset_bottom = 64
	button.pressed.connect(open_town)
	$TouchUI.add_child(button)
	_build_defeat_ui()
	$MeleeHero.died.connect(_on_hero_died)
	get_viewport().size_changed.connect(_layout_safe_ui)
	_layout_safe_ui.call_deferred()
	# Only the shipping main scene auto-loads user progress. Fixtures stay isolated.
	if get_tree().current_scene == self:
		preload("res://scripts/utilities/desktop_window.gd").configure(get_tree().root)
		start_saving.call_deferred(persistence_path)
	_finish_title_startup.call_deferred()

func start_saving(path: String = "user://saves/autosave.json") -> void:
	if is_instance_valid(save_session): return
	titles_ready=false
	save_session = preload("res://scripts/persistence/save_session.gd").new()
	add_child(save_session)
	save_session.start(self, path)
	var label := Label.new()
	label.name = "SaveStatus"
	_save_label=label
	label.position = Vector2(24, 100)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 16)
	label.text = save_session.status
	save_session.status_changed.connect(func(text: String): label.text = text)
	$TouchUI.add_child(label)
	var recovery := preload("res://scenes/ui/save_recovery_menu.gd").new()
	recovery.name="SaveRecoveryMenu"
	recovery.session=save_session
	recovery.status_label=label
	$TouchUI.add_child(recovery)
	_layout_safe_ui.call_deferred()
	_finish_title_startup.call_deferred()

func _build_defeat_ui() -> void:
	_defeat_ui = PanelContainer.new()
	_defeat_ui.name = "DefeatPanel"
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color("142432")
	frame.border_color = Color("aac6ce")
	frame.set_border_width_all(2)
	frame.set_content_margin_all(16)
	_defeat_ui.add_theme_stylebox_override("panel", frame)
	var column := VBoxContainer.new()
	_defeat_ui.add_child(column)
	var label := Label.new()
	label.text = "Defeated"
	_defeat_title=label
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 30)
	column.add_child(label)
	var note := Label.new()
	note.text = "Weapon wear and collected town parts remain."
	note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	_defeat_note=note
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_defeat_note_holder=Control.new()
	column.add_child(_defeat_note_holder)
	_defeat_note_holder.add_child(note)
	note.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var retry := Button.new()
	retry.text = "Retry floor"
	_retry=retry
	retry.custom_minimum_size.y = 56
	retry.pressed.connect(retry_floor)
	column.add_child(retry)
	$TouchUI.add_child(_defeat_ui)
	_defeat_ui.hide()

func retry_floor() -> bool:
	if not $MeleeHero.is_dead() or is_instance_valid(town_view):
		return false
	$MeleeHero.current_hp = $MeleeHero.max_hp
	$MeleeHero.hp_changed.emit($MeleeHero.current_hp, $MeleeHero.max_hp)
	$MeleeHero._on_weapon_equipped($MeleeHero.weapon_inventory.equipped_weapon)
	_defeat_ui.hide()
	_load_floor()
	return true

func open_town() -> void:
	if is_instance_valid(town_view) or $MeleeHero.is_dead():
		return
	major_title.cancel()
	_previous_process_mode = process_mode
	$TouchUI.hide()
	hide()
	process_mode = Node.PROCESS_MODE_DISABLED
	_town_layer = CanvasLayer.new()
	_town_layer.layer = 20
	var container := SubViewportContainer.new()
	# Keep forwarding native touches to pause-menu controls in the child viewport.
	container.process_mode = Node.PROCESS_MODE_ALWAYS
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.stretch = true
	var viewport := SubViewport.new()
	# World simulation still pauses; individual menu controls opt into ALWAYS.
	viewport.process_mode = Node.PROCESS_MODE_PAUSABLE
	viewport.own_world_3d = true
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(viewport)
	_town_layer.add_child(container)
	get_tree().root.add_child(_town_layer)
	town_view = load("res://scenes/georama/georama_manager.tscn").instantiate()
	town_view.closed.connect(close_town)
	viewport.add_child(town_view)

func close_town() -> void:
	if not is_instance_valid(town_view):
		return
	_town_layer.queue_free()
	town_view = null
	process_mode = _previous_process_mode
	show()
	$TouchUI.show()
	preload("res://scripts/utilities/services.gd").game_state().set_mode(0)

func _exit_tree() -> void:
	if is_instance_valid(major_title): major_title.cancel()
	if is_instance_valid(_town_layer):
		_town_layer.queue_free()

func _load_floor() -> void:
	if not floor_generator.generate(dungeon_seed + (floor_number - 1) * 1009, floor_number):
		push_error("Dungeon generation failed for seed %d, floor %d" % [dungeon_seed, floor_number])
		return
	$MeleeHero.position = floor_generator.cell_to_world(floor_generator.spawn_cell) + Vector3.UP * 0.1
	$MeleeHero.velocity = Vector3.ZERO
	$MeleeHero.camera_rig.snap()
	if titles_ready: _announce_entry()

func _queue_next_floor() -> void:
	# Exit triggers run during physics; replace collision objects afterward.
	_advance_floor.call_deferred()

func _advance_floor() -> void:
	Services.game_state().record_floor_clear(floor_number)
	floor_number += 1
	_load_floor()

func _layout_safe_ui() -> void:
	if _travel_button==null or _retry==null: return
	var safe := Layout.safe_rect(get_viewport())
	var m := Layout.metrics(get_viewport())
	Layout.button(_travel_button,m,true)
	_travel_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_travel_button.size=Vector2(maxf(230,_travel_button.get_combined_minimum_size().x),m.primary)
	_travel_button.position=Vector2(safe.end.x-_travel_button.size.x,safe.position.y)
	Layout.button(_retry,m,true)
	_retry.custom_minimum_size.y=maxf(56,m.primary)
	_defeat_title.add_theme_font_size_override("font_size",maxi(30,m.body+4))
	_defeat_note.add_theme_font_size_override("font_size",m.body)
	var width: float=minf(safe.size.x,maxf(440,m.body*28))
	var note_height := Layout.text_height(_defeat_note.text,width-32,m.body)
	_defeat_note_holder.custom_minimum_size=Vector2(width-32,note_height)
	_defeat_size=Vector2(width,32+ThemeDB.fallback_font.get_height(maxi(30,m.body+4))+note_height+maxf(56,m.primary)+2*m.gap)
	_settle_defeat.call_deferred()
	if _save_label!=null:
		_save_label.add_theme_font_size_override("font_size",m.secondary)
		_save_label.position=safe.position+Vector2(0,_hud.get_combined_minimum_size().y+m.gap)
		var recovery := get_node_or_null("TouchUI/SaveRecoveryMenu")
		if recovery!=null: recovery.refresh()
func _settle_defeat() -> void:
	_defeat_ui.size=_defeat_size
	_defeat_ui.position=Layout.safe_rect(get_viewport()).get_center()-_defeat_ui.size/2
func _on_hero_died() -> void:
	_defeat_ui.show()
	major_title.cancel()
func _entry_key() -> StringName:
	return StringName("biome:%s:floor:%d"%[preload("res://scripts/utilities/dungeon_biomes.gd").for_floor(floor_number),floor_number])
func _announce_entry() -> void:
	var key := _entry_key()
	if key==last_announced_entry: return
	last_announced_entry=key
	if is_instance_valid(town_view) or $MeleeHero.is_dead(): return
	var biome: String=preload("res://scripts/utilities/dungeon_biomes.gd").for_floor(floor_number)
	var names := {"foundry":"FOUNDRY","frost":"FROZEN FRONTIER","overgrown_rail":"OVERGROWN RAILS"}
	major_title.show_title(&"biome",names[biome],key)
func _finish_title_startup() -> void:
	if titles_ready: return
	titles_ready=true
	_announce_entry()
func _on_character_unlocked(id: String) -> void:
	if titles_ready and not is_instance_valid(town_view) and not $MeleeHero.is_dead():
		major_title.show_title(&"unlock","DEVOURER UNLOCKED",StringName("unlock:"+id))
