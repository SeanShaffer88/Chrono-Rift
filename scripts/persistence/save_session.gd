extends Node
## Main-scene owned autosave. Tests/fixtures opt in with an isolated file path.
signal status_changed(text: String)
signal diagnostic_changed(diagnostic: Dictionary)
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
var diagnostic: Dictionary={}
var _last_logged_diagnostic := ""
var _recovering := false

func start(owner_dungeon: Node, path: String = "user://saves/autosave.json") -> void:
	print("SAVE_BUILD ",ProjectSettings.get_setting("application/config/version","unknown"))
	dungeon = owner_dungeon
	process_mode = Node.PROCESS_MODE_ALWAYS
	store = _make_store(path)
	var result: Dictionary = store.read_save()
	_publish_diagnostic()
	_recovered = result.status == "recovered"
	if result.status in ["ok", "recovered"]:
		_restore(result.data)
		_set_status("Recovered backup save" if _recovered else "Save loaded")
	elif result.status=="missing" and not store.blocked:
		var fresh := Data.make_fresh_snapshot(_fresh_seed())
		if fresh.is_empty():
			_set_status("Save unavailable — fresh expedition validation failed")
			return
		var error: Error=store.write_save(fresh)
		# No existing save was present. A failed write still keeps this chosen run in memory.
		_restore(fresh)
		_publish_diagnostic()
		_set_status("Saved" if error==OK else "Save failed — retrying this expedition")
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

func _make_store(path: String) -> RefCounted:
	return Store.new(path,Data.validate)

func _fresh_seed() -> int:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var chosen := int(rng.randi())-2147483648
	if is_instance_valid(dungeon) and chosen==dungeon.dungeon_seed:
		chosen=-2147483648 if chosen==2147483647 else chosen+1
	return chosen

func _listen(event: Signal) -> void:
	var callback := func(_a: Variant = null, _b: Variant = null, _c: Variant = null): queue_save()
	event.connect(callback)
	_connections.append({"signal": event, "callback": callback})

func queue_save() -> void:
	if _recovering: return
	if not _dirty:
		_dirty_elapsed = 0.0
	_dirty = true

func _process(delta: float) -> void:
	if not _loaded or _recovering: return
	_elapsed += delta
	_dirty_elapsed += delta
	if (_dirty and _dirty_elapsed >= 0.3) or _elapsed >= 5.0:
		flush()

func flush() -> Error:
	if _recovering or not _loaded or not is_instance_valid(dungeon) or dungeon.floor_generator.cleared:
		return ERR_BUSY
	_elapsed = 0.0
	_dirty = false
	if store.blocked:
		_publish_diagnostic()
		return ERR_INVALID_DATA
	_set_status("Saving…")
	var error: Error = store.write_save(Data.capture(Services.game_state(), dungeon))
	_publish_diagnostic()
	_set_status(("Saved (backup recovered)" if _recovered else "Saved") if error == OK else "Save unavailable — progress not saved")
	return error
func _publish_diagnostic() -> void:
	diagnostic=store.last_diagnostic.duplicate()
	var encoded := JSON.stringify(diagnostic)
	if encoded!=_last_logged_diagnostic:
		print("SAVE_DIAGNOSTIC ",encoded)
		_last_logged_diagnostic=encoded
		diagnostic_changed.emit(diagnostic.duplicate())
func can_start_fresh() -> bool:
	return not _recovering and store.blocked and diagnostic.get("stage") in ["read_primary","read_backup"] and diagnostic.get("reason") in ["unsupported_schema","oversize","json_invalid","checksum_invalid","payload_invalid","validation_failed"]
func display_status() -> String:
	if _recovered and not store.blocked and diagnostic.get("stage") in ["read_primary","read_backup"]: return status
	match diagnostic.get("reason","none"):
		"unsupported_schema": return "Save version %s unsupported."%str(diagnostic.encountered_schema).trim_suffix(".0")
		"json_invalid","payload_invalid","checksum_invalid": return "Save file failed its integrity check."
		"validation_failed": return "Existing save data is invalid." if diagnostic.get("stage") in ["read_primary","read_backup"] else "Current state could not be saved."
		"recovery_pending": return "Save recovery needs attention."
		"open_failed": return "Save file could not be opened."
		"oversize": return "Save exceeds the supported size."
		"write_failed","rename_failed": return "Save storage operation failed."
	return status
func details(include_status: bool=true) -> String:
	var message := display_status() if include_status else ""
	if diagnostic.get("reason")=="unsupported_schema":
		message+="\nThis save is from an %s game format."%("earlier" if float(diagnostic.encountered_schema)<Store.VERSION else "newer")
	message+="\nBuild: %s\nSave format: %s; required: %d\nOperation: %s\nStorage error: %s\nFile bytes: %d"%[ProjectSettings.get_setting("application/config/version","unknown"),str(diagnostic.get("encountered_schema",-1)).trim_suffix(".0"),Store.VERSION,str(diagnostic.get("stage","")).replace("_"," ").capitalize(),"None" if int(diagnostic.get("error",OK))==OK else error_string(int(diagnostic.error)),int(diagnostic.get("bytes",0))]
	return message.strip_edges()
func start_fresh_with_backup() -> Dictionary:
	if _recovering or not can_start_fresh():
		return {"ok":false,"error":ERR_BUSY,"reason":"recovery_pending","archive_path":"","rollback_ok":true}
	var fresh := Data.make_fresh_snapshot(_fresh_seed())
	if fresh.is_empty(): return {"ok":false,"error":ERR_INVALID_DATA,"reason":"validation_failed","archive_path":"","rollback_ok":true}
	_recovering=true
	var paused := get_tree().paused
	get_tree().paused=true
	for joystick: Node in get_tree().get_nodes_in_group("virtual_joystick"):
		if joystick.has_method("_release"): joystick._release()
	for control: Node in dungeon.get_node("TouchUI").get_children():
		if control.has_method("_release"): control._release()
	var result: Dictionary=store.start_fresh_with_backup(fresh)
	if result.ok:
		if is_instance_valid(dungeon.town_view): dungeon.close_town()
		_restore(fresh)
		_recovered=false
		_dirty=false
		_elapsed=0
		_dirty_elapsed=0
	_publish_diagnostic()
	_set_status("Saved" if result.ok else "Recovery did not complete — saving remains paused")
	get_tree().paused=paused
	_recovering=false
	return result

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
