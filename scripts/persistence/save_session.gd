extends Node
## Main-scene owned autosave. Tests/fixtures opt in with an isolated file path.
signal status_changed(text: String)
const Data = preload("res://scripts/persistence/save_data.gd")
const Store = preload("res://scripts/persistence/save_store.gd")
const Services = preload("res://scripts/utilities/services.gd")
var dungeon: Node
var store: RefCounted
var status := "Autosave ready"
var _elapsed := 0.0
var _dirty := false
var _dirty_elapsed := 0.0
var _loaded := false
var _recovered := false
var _connections: Array[Dictionary] = []

func start(owner_dungeon: Node, path: String = "user://saves/autosave.json") -> void:
	dungeon = owner_dungeon
	process_mode = Node.PROCESS_MODE_ALWAYS
	store = Store.new(path, Data.validate)
	var result: Dictionary = store.read_save()
	_recovered = result.status == "recovered"
	if result.status in ["ok", "recovered"]:
		_restore(result.data)
		_set_status("Recovered backup save" if _recovered else "Save loaded")
	elif result.status != "missing":
		_set_status("Save unavailable — progress not saved")
	_loaded = true
	var state := Services.game_state()
	for inventory: Node in state.character_inventories.values():
		_listen(inventory.inventory_changed)
		_listen(inventory.equipped_changed)
	for name_value in ["atla_collected", "player_damaged", "weapon_durability_changed", "character_swapped", "georama_satisfaction_updated", "dungeon_gate_unlocked", "floor_cleared"]:
		_listen(Signal(Services.event_bus(), name_value))
	_listen(dungeon.get_node("MeleeHero").hp_changed)
	queue_save()

func _listen(event: Signal) -> void:
	var callback := func(_a: Variant = null, _b: Variant = null, _c: Variant = null): queue_save()
	event.connect(callback)
	_connections.append({"signal": event, "callback": callback})

func queue_save() -> void:
	if not _dirty:
		_dirty_elapsed = 0.0
	_dirty = true

func _process(delta: float) -> void:
	if not _loaded: return
	_elapsed += delta
	_dirty_elapsed += delta
	if (_dirty and _dirty_elapsed >= 0.3) or _elapsed >= 5.0:
		flush()

func flush() -> Error:
	if not _loaded or not is_instance_valid(dungeon) or dungeon.floor_generator.cleared:
		return ERR_BUSY
	_elapsed = 0.0
	_dirty = false
	if store.blocked:
		return ERR_INVALID_DATA
	_set_status("Saving…")
	var error: Error = store.write_save(Data.capture(Services.game_state(), dungeon))
	_set_status(("Saved (backup recovered)" if _recovered else "Saved") if error == OK else "Save unavailable — progress not saved")
	return error

func _restore(data: Dictionary) -> void:
	Data.apply_state(Services.game_state(), data)
	dungeon.dungeon_seed = int(data.dungeon_seed)
	dungeon.floor_number = int(data.floor_number)
	dungeon._load_floor()
	dungeon.floor_generator.restore_progress(data.floor)
	_restore_actor(dungeon.get_node("MeleeHero"), data.hero, false)
	dungeon.get_node("TouchUI/DefeatPanel").visible = int(data.hero.hp) == 0
	if not data.town_visit.is_empty() and int(data.hero.hp) > 0:
		dungeon.open_town()
		dungeon.town_view.set_editing(data.town_visit.editing)
		_restore_actor(dungeon.town_view.get_node("MeleeHero"), data.town_visit.hero, true)

func _restore_actor(hero: Node3D, record: Dictionary, town: bool) -> void:
	var position_value := Data.unpack_vector(record.position)
	if town:
		# Valid saved town coordinates can include exterior hills and interiors.
		if position_value.x < -30 or position_value.x > 158 or position_value.z < -30 or position_value.z > 158 or position_value.y < -0.5:
			position_value = Vector3(62, 0.1, 70)
	else:
		var cell := Vector2i(roundi(position_value.x / 2), roundi(position_value.z / 2))
		if not dungeon.floor_generator.layout.walkable.has(cell) or position_value.y < -0.5 or position_value.y > 4:
			position_value = dungeon.floor_generator.cell_to_world(dungeon.floor_generator.spawn_cell) + Vector3.UP * 0.1
	hero.position = position_value
	hero.velocity = Vector3.ZERO
	hero.current_hp = int(record.hp)
	hero.face_direction(Data.unpack_vector(record.facing))
	hero.camera_rig.restore_view(float(record.yaw),float(record.pitch))
	hero.hp_changed.emit(hero.current_hp, hero.max_hp)

func _set_status(text: String) -> void:
	status = text
	status_changed.emit(status)

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_CLOSE_REQUEST]:
		flush()

func _exit_tree() -> void:
	for record: Dictionary in _connections:
		if not record.signal.is_null() and record.signal.is_connected(record.callback):
			record.signal.disconnect(record.callback)
