extends "res://tests/test_harness_template.gd"
const Data=preload("res://scripts/persistence/save_data.gd")
const Store=preload("res://scripts/persistence/save_store.gd")
const Recovery=preload("res://scripts/persistence/save_recovery.gd")
class FaultRecovery extends "res://scripts/persistence/save_recovery.gd":
	var fault := ""
	func _copy_file(from: String,to: String) -> Error:
		if fault=="copy" and to.begins_with(ARCHIVES): return ERR_FILE_CANT_WRITE
		var error := super._copy_file(from,to)
		if error==OK and fault=="verify" and to.begins_with(ARCHIVES): _write_file(to,"changed archive copy")
		return error
	func _write_file(path: String,text: String) -> Error:
		if fault=="stage" and ".fresh-" in path: return ERR_FILE_CANT_WRITE
		if fault=="complete_journal" and ".journal-" in path and '"complete"' in text: return ERR_FILE_CANT_WRITE
		return super._write_file(path,text)
	func _rename_file(from: String,to: String) -> Error:
		if fault=="primary" and ".fresh-" in from and to==store.path: return ERR_CANT_CREATE
		if fault=="journal" and to.ends_with(".recovery.json"): return ERR_CANT_CREATE
		if fault in ["commit","rollback"] and ".fresh-" in from and to==store.path+".bak": return ERR_CANT_CREATE
		if fault=="rollback" and ".rollback-" in from: return ERR_CANT_CREATE
		return super._rename_file(from,to)
var paths: Array[String]=[]
var transactions: Array[RefCounted]=[]
var extra_archives: Array[String]=[]
func write(path: String,text: String) -> void:
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_string(text)
	file.close()
func make_old(label: String) -> RefCounted:
	var path := "user://verification-recovery-%d-%s.json"%[OS.get_process_id(),label]
	paths.append(path)
	for index in Recovery.SUFFIXES.size():
		write(path+Recovery.SUFFIXES[index],JSON.stringify({"version":3,"preserved_marker":label+str(index)}))
	var store := Store.new(path,Data.validate)
	store.read_save()
	return store
func hashes(store: RefCounted) -> Array[String]:
	var result: Array[String]=[]
	for suffix: String in Recovery.SUFFIXES: result.append(FileAccess.get_sha256(store.path+suffix))
	return result
func run_assertions() -> void:
	var state=root.get_node("GameState")
	state.reset()
	state.swap_character("riftwarden")
	state.thirst=41
	var fresh := Data.make_fresh_snapshot(1337)
	check(Data.validate(fresh) and fresh.floor_number==1 and fresh.hero.hp==100 and fresh.thirst==100 and not fresh.secret_unlocked,"Isolated fresh candidate validates with default progress and health")
	check(state.active_character_id=="riftwarden" and state.thirst==41,"Preparing a candidate leaves live state and owned inventories unchanged")
	var plan=preload("res://scenes/dungeon/floor_generator.gd").new()
	plan.generate(1337,1,false)
	var exact := true
	for entry: Dictionary in fresh.floor.encounters:
		exact=exact and entry.hp==(preload("res://scripts/combat/enemy_profiles.gd").profile(entry.id).hp if plan.encounter_plan.has(entry.id) else 0)
	check(exact and fresh.hero.position==Data.pack_vector(plan.cell_to_world(plan.spawn_cell)+Vector3.UP*0.1),"Fresh snapshot reuses exact deterministic floor spawn and encounter plan without building geometry")
	plan.free()
	var store := make_old("success")
	var before := hashes(store)
	var recovery := Recovery.new(store)
	transactions.append(recovery)
	var result: Dictionary=recovery.run(fresh)
	check(result.ok and not store.blocked and store.read_save().status=="ok","Explicit recovery commits a readable current-format save")
	check(FileAccess.get_sha256(store.path)==FileAccess.get_sha256(store.path+".bak") and not Recovery.journal_state(store.path).pending,"Fresh primary and backup match with terminal completed journal")
	var archived := true
	for index in Recovery.NAMES.size(): archived=archived and FileAccess.get_sha256(result.archive_path.path_join(Recovery.NAMES[index]))==before[index]
	check(archived and FileAccess.file_exists(result.archive_path.path_join("manifest.json")),"All four original files are retained byte-for-byte in a verified archive")
	check(state.active_character_id=="riftwarden" and state.thirst==41,"Store commit never resets live game state")
	var repeat: Dictionary=store.start_fresh_with_backup(fresh)
	check(not repeat.ok,"A repeated recovery cannot reset an already healthy current save")
	for fault in ["copy","verify","stage","journal","primary","commit","complete_journal","rollback"]:
		store=make_old(fault)
		before=hashes(store)
		var injected := FaultRecovery.new(store)
		injected.fault=fault
		transactions.append(injected)
		result=injected.run(fresh)
		check(not result.ok and store.blocked,"Injected %s failure never reports success or enables autosave"%fault)
		var after_failed := hashes(store)
		check(not injected.run(fresh).ok and hashes(store)==after_failed,"The same %s transaction object cannot run a second destructive attempt"%fault)
		if fault not in ["copy","verify"]:
			var archive_exact := true
			for index in Recovery.NAMES.size(): archive_exact=archive_exact and FileAccess.get_sha256(result.archive_path.path_join(Recovery.NAMES[index]))==before[index]
			check(archive_exact,"All original archive hashes survive the %s fault"%fault)
		if fault!="rollback":
			check(hashes(store)==before,"Injected %s failure preserves or restores all active bytes"%fault)
		else:
			check(not result.rollback_ok and Recovery.journal_state(store.path).pending,"Rollback failure retains a pending journal and reports incomplete restoration")
			var reopened := Store.new(store.path,Data.validate)
			check(reopened.read_save().status=="recovery_pending" and reopened.write_save(fresh)!=OK,"Restart with pending journal blocks ordinary writes even with readable fresh primary")
			var journal_before := FileAccess.get_sha256(store.path+".recovery.json")
			check(not reopened.start_fresh_with_backup(fresh).ok and FileAccess.get_sha256(store.path+".recovery.json")==journal_before,"A second explicit request cannot overwrite a pending recovery journal")
	store=make_old("invalid")
	before=hashes(store)
	check(not store.start_fresh_with_backup({}).ok and hashes(store)==before,"Invalid fresh candidate is rejected before any active bytes change")
	for journal in ["truncated",JSON.stringify({"version":1,"phase":"pending","archive":"../../outside"})]:
		write(store.path+".recovery.json",journal)
		check(Recovery.journal_state(store.path).pending and Recovery.journal_state(store.path).archive.is_empty(),"Malformed or traversal journal remains blocked without following an untrusted path")
	store=make_old("session")
	var dungeon=load("res://scenes/dungeon/dungeon_manager.tscn").instantiate()
	root.add_child(dungeon)
	dungeon.floor_number=5
	dungeon._load_floor()
	dungeon.get_node("MeleeHero").current_hp=39
	dungeon.start_saving(store.path)
	check(dungeon.save_session.can_start_fresh() and dungeon.save_session.diagnostic.reason=="unsupported_schema","Preserved unsupported session exposes only the explicit recovery action")
	var menu=dungeon.get_node("TouchUI/SaveRecoveryMenu")
	var original_hashes := hashes(store)
	for frame in 4: await process_frame
	for pressed in [true,false]:
		var touch := InputEventScreenTouch.new()
		touch.index=78
		touch.position=menu.launch.get_global_rect().get_center()
		touch.pressed=pressed
		root.push_input(touch,true)
		await process_frame
	for frame in 4: await process_frame
	check(menu.opened and paused and menu.confirm.visible,"Actual Viewport touch opens recovery outside joystick capture and pauses gameplay")
	var safe := preload("res://scripts/utilities/menu_layout.gd").safe_rect(root)
	check(safe.grow(1).encloses(menu.panel.get_global_rect()) and menu.notes.body_holder.get_global_rect().end.y<=menu.actions.get_global_rect().position.y+1,"Recovery text and pinned controls stay bounded without overlap")
	menu.close_details()
	check(not paused and hashes(store)==original_hashes and dungeon.floor_number==5,"Cancel closes recovery without changing live progress or any existing bytes")
	var changed: Array=[]
	dungeon.save_session.diagnostic_changed.connect(func(value: Dictionary): changed.append(value))
	dungeon.save_session.flush()
	dungeon.save_session.flush()
	check(changed.is_empty(),"Repeated identical blocked autosaves do not repeat diagnostic events")
	var metadata: String=JSON.stringify(dungeon.save_session.diagnostic)
	check(dungeon.save_session.diagnostic.size()==6 and not "user://" in metadata and not "preserved_marker" in metadata,"Structured diagnostics expose only bounded reason/schema/error metadata")
	result=dungeon.save_session.start_fresh_with_backup()
	extra_archives.append(result.archive_path)
	check(result.ok and state.active_character_id=="melee_hero" and not state.secret_unlocked and state.thirst==100 and dungeon.floor_number==1 and dungeon.get_node("MeleeHero").current_hp==100,"Session applies fresh live state only after verified commit succeeds")
	check(not dungeon.save_session.start_fresh_with_backup().ok,"Double-click after success cannot start another reset")
	dungeon.queue_free()
	await process_frame
	dungeon=load("res://scenes/dungeon/dungeon_manager.tscn").instantiate()
	root.add_child(dungeon)
	dungeon.start_saving(store.path)
	check(dungeon.save_session.status=="Save loaded" and dungeon.floor_number==1 and dungeon.get_node("MeleeHero").current_hp==100,"Fresh committed snapshot survives actual manager recreation")
	dungeon.queue_free()
	await process_frame
	var link_root := "user://verification-recovery-link-%d"%OS.get_process_id()
	DirAccess.make_dir_recursive_absolute(link_root)
	var link_source := link_root.path_join("source.json")
	var link_target := link_root.path_join("link.json")
	write(link_source,"protected link target")
	var directory := DirAccess.open(link_root)
	var link_error := directory.create_link(ProjectSettings.globalize_path(link_source),ProjectSettings.globalize_path(link_target))
	if link_error==OK:
		check(not Recovery.safe_local_path(link_target),"Native symbolic-link owned file is rejected before following its target")
		var linked_store := Store.new(link_target,Data.validate)
		check(linked_store.read_save().status=="invalid" and not linked_store.start_fresh_with_backup(fresh).ok and FileAccess.get_file_as_string(link_source)=="protected link target","Link recovery preserves the external target bytes")
		DirAccess.remove_absolute(link_target)
	else:
		if OS.get_name()=="Linux": check(false,"Linux native symlink fixture creation is required")
		else: print("RECOVERY_SYMLINK_SKIP platform=",OS.get_name()," error=",link_error)
	DirAccess.remove_absolute(link_source)
	DirAccess.remove_absolute(link_root)
	for transaction: RefCounted in transactions:
		if not transaction.archive_path.is_empty():
			for name: String in Recovery.NAMES+ ["manifest.json"]:
				var file: String=transaction.archive_path.path_join(name)
				if FileAccess.file_exists(file): DirAccess.remove_absolute(file)
			DirAccess.remove_absolute(transaction.archive_path)
	for archive: String in extra_archives:
		for name: String in Recovery.NAMES+["manifest.json"]: DirAccess.remove_absolute(archive.path_join(name))
		DirAccess.remove_absolute(archive)
	for path in paths:
		var owned: Array=Recovery.SUFFIXES+[".recovery.json"]
		var ids: Array[String]=[]
		for transaction: RefCounted in transactions:
			if transaction.store.path==path and not transaction.transaction.is_empty(): ids.append(transaction.transaction)
		if path.ends_with("-session.json"):
			for archive: String in extra_archives: ids.append(archive.get_file())
		for id: String in ids:
			owned.append_array([".fresh-"+id+".primary",".fresh-"+id+".backup",".journal-"+id])
			for index in 4: owned.append(".rollback-"+id+"-"+str(index))
		for suffix: String in owned:
			if FileAccess.file_exists(path+suffix): DirAccess.remove_absolute(path+suffix)
	state.reset()
