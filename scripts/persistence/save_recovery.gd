extends RefCounted
## Explicit local archive transaction. Startup only blocks; it never replays a journal.
const ARCHIVES := "user://saves/archives"
const SUFFIXES := ["",".bak",".tmp",".bak.tmp"]
const NAMES := ["primary","backup","temporary","backup_temporary"]
var store: RefCounted
var transaction := ""
var archive_path := ""
var originals: Array[Dictionary]=[]
var fresh_hash := ""
var _used := false
func _init(owner_store: RefCounted) -> void: store=owner_store
static func safe_local_path(path: String) -> bool:
	if not path.begins_with("user://") or "\\" in path: return false
	var root := ProjectSettings.globalize_path("user://").replace("\\","/").simplify_path().trim_suffix("/")
	var relative := path.trim_prefix("user://")
	var parts := relative.split("/",false)
	for part in parts:
		if part in [".",".."] or not part.is_valid_filename(): return false
	if OS.get_name()=="Android":
		var provided := OS.get_user_data_dir().replace("\\","/").simplify_path().trim_suffix("/")
		if root!=provided or DirAccess.open(root)==null: return false
	else:
		var parent := DirAccess.open(root.get_base_dir())
		if parent==null or parent.is_link(root.get_file()): return false
	var current := root
	for index in parts.size():
		var part: String=parts[index]
		var directory := DirAccess.open(current)
		if directory==null: return false
		if directory.is_link(part): return false
		current=current.path_join(part)
		if directory.file_exists(part): return index==parts.size()-1
		if not directory.dir_exists(part): return true
	return true
static func paths_safe(path: String) -> bool:
	for suffix: String in SUFFIXES+[".recovery.json"]:
		if not safe_local_path(path+suffix): return false
	return safe_local_path(ARCHIVES)
static func valid_archive_name(value: Variant) -> bool:
	if not value is String or value.length()>64 or value.count("-")!=1: return false
	var halves: PackedStringArray=value.split("-",true)
	return halves.size()==2 and not halves[0].is_empty() and not halves[1].is_empty() and halves[0].is_valid_int() and halves[1].is_valid_int() and not value.begins_with("-")
static func journal_state(path: String) -> Dictionary:
	var journal := path+".recovery.json"
	if not safe_local_path(journal): return {"pending":true,"archive":""}
	if not FileAccess.file_exists(journal): return {"pending":false,"archive":""}
	var file := FileAccess.open(journal,FileAccess.READ)
	if file==null: return {"pending":true,"archive":""}
	var bounded := file.get_length()<=4096
	var text := file.get_as_text() if bounded else ""
	file.close()
	var parser := JSON.new()
	if parser.parse(text)!=OK: return {"pending":true,"archive":""}
	var data: Variant=parser.data
	if not data is Dictionary or data.get("version")!=1 or not valid_archive_name(data.get("archive")):
		return {"pending":true,"archive":""}
	return {"pending":data.get("phase") not in ["complete","rolled_back"],"archive":ARCHIVES.path_join(data.archive)}
func _metadata(path: String) -> Dictionary:
	if not safe_local_path(path): return {"ok":false,"error":ERR_UNAUTHORIZED}
	var file := FileAccess.open(path,FileAccess.READ)
	if file==null: return {"ok":false,"error":FileAccess.get_open_error()}
	var bytes := file.get_length()
	file.close()
	var sha := FileAccess.get_sha256(path)
	return {"ok":sha.length()==64,"error":OK if sha.length()==64 else ERR_FILE_CANT_READ,"bytes":bytes,"sha256":sha}
func _matches(path: String,record: Dictionary) -> bool:
	var actual := _metadata(path)
	return actual.ok and actual.bytes==record.bytes and actual.sha256==record.sha256
func _copy_file(from: String,to: String) -> Error:
	return DirAccess.copy_absolute(from,to) if safe_local_path(from) and safe_local_path(to) else ERR_UNAUTHORIZED
func _rename_file(from: String,to: String) -> Error:
	return DirAccess.rename_absolute(from,to) if safe_local_path(from) and safe_local_path(to) else ERR_UNAUTHORIZED
func _remove_file(path: String) -> Error:
	return DirAccess.remove_absolute(path) if safe_local_path(path) else ERR_UNAUTHORIZED
func _write_file(path: String,text: String) -> Error:
	if not safe_local_path(path): return ERR_UNAUTHORIZED
	var file := FileAccess.open(path,FileAccess.WRITE)
	if file==null: return FileAccess.get_open_error()
	file.store_string(text)
	file.flush()
	var error := file.get_error()
	file.close()
	if error!=OK: return error
	return OK if FileAccess.get_sha256(path)==text.sha256_text() else ERR_FILE_CANT_WRITE
func _result(ok: bool,error: int,reason: String,rollback_ok: bool=true) -> Dictionary:
	return {"ok":ok,"error":error,"reason":reason,"archive_path":archive_path,"rollback_ok":rollback_ok}
func _fail(error: int,reason: String,stage: String="recovery") -> Dictionary:
	store.blocked=true
	store.last_diagnostic=store._diagnostic(reason,stage,error)
	return _result(false,error,reason)
func _journal(phase: String) -> Error:
	var stage: String=store.path+".journal-"+transaction
	var text := JSON.stringify({"version":1,"phase":phase,"archive":transaction})
	var error := _write_file(stage,text)
	if error!=OK: return error
	return _rename_file(stage,store.path+".recovery.json")
func _rollback() -> bool:
	var success := true
	for index in originals.size():
		var record: Dictionary=originals[index]
		var target: String=store.path+SUFFIXES[index]
		if record.present:
			if _matches(target,record): continue
			var stage: String=store.path+".rollback-"+transaction+"-"+str(index)
			if _copy_file(archive_path.path_join(NAMES[index]),stage)!=OK or not _matches(stage,record) or _rename_file(stage,target)!=OK or not _matches(target,record): success=false
		elif FileAccess.file_exists(target):
			if FileAccess.get_sha256(target)!=fresh_hash or _remove_file(target)!=OK: success=false
	return success
func _after_touch_failure(error: int,reason: String) -> Dictionary:
	var rollback_ok := _rollback()
	if rollback_ok and _journal("rolled_back")!=OK: rollback_ok=false
	store.blocked=true
	store.last_diagnostic=store._diagnostic(reason if rollback_ok else "recovery_pending","recovery",error)
	return _result(false,error,reason,rollback_ok)
func run(fresh: Dictionary) -> Dictionary:
	if _used: return _result(false,ERR_BUSY,"recovery_pending")
	_used=true
	if not paths_safe(store.path): return _fail(ERR_UNAUTHORIZED,"open_failed")
	if journal_state(store.path).pending: return _fail(ERR_BUSY,"recovery_pending")
	if not store.blocked or store.last_diagnostic.stage not in ["read_primary","read_backup"] or store.last_diagnostic.reason not in ["unsupported_schema","oversize","json_invalid","checksum_invalid","payload_invalid","validation_failed"]:
		return _result(false,ERR_UNAVAILABLE,"validation_failed")
	if not store.validator.call(fresh): return _fail(ERR_INVALID_DATA,"validation_failed","validate_capture")
	if not store.path.begins_with("user://") or ".." in store.path or not store.path.get_file().is_valid_filename():
		return _fail(ERR_INVALID_PARAMETER,"write_failed")
	transaction=str(int(Time.get_unix_time_from_system()))+"-"+str(Time.get_ticks_usec())
	archive_path=ARCHIVES.path_join(transaction)
	if not safe_local_path(archive_path): return _fail(ERR_UNAUTHORIZED,"open_failed")
	if DirAccess.dir_exists_absolute(archive_path): return _fail(ERR_ALREADY_EXISTS,"write_failed")
	var error := DirAccess.make_dir_recursive_absolute(ARCHIVES)
	if error!=OK: return _fail(error,"write_failed")
	if not safe_local_path(ARCHIVES): return _fail(ERR_UNAUTHORIZED,"open_failed")
	var archive_root := DirAccess.open(ARCHIVES)
	if archive_root==null: return _fail(DirAccess.get_open_error(),"open_failed")
	error=archive_root.make_dir(transaction)
	if error!=OK: return _fail(error,"write_failed")
	for index in SUFFIXES.size():
		var source: String=store.path+SUFFIXES[index]
		var record := {"present":FileAccess.file_exists(source)}
		if record.present:
			var before := _metadata(source)
			if not before.ok: return _fail(before.error,"open_failed")
			record.bytes=before.bytes
			record.sha256=before.sha256
			error=_copy_file(source,archive_path.path_join(NAMES[index]))
			if error!=OK: return _fail(error,"write_failed")
			if not _matches(source,record) or not _matches(archive_path.path_join(NAMES[index]),record): return _fail(ERR_FILE_CORRUPT,"checksum_invalid")
		originals.append(record)
	var manifest := JSON.stringify({"version":1,"transaction":transaction,"files":originals})
	error=_write_file(archive_path.path_join("manifest.json"),manifest)
	if error!=OK or FileAccess.get_file_as_string(archive_path.path_join("manifest.json"))!=manifest: return _fail(ERR_FILE_CANT_WRITE,"write_failed")
	var payload := JSON.stringify(fresh)
	var encoded := JSON.stringify({"version":store.VERSION,"payload":payload,"sha256":payload.sha256_text()})
	if encoded.to_utf8_buffer().size()>store.MAX_BYTES: return _fail(ERR_OUT_OF_MEMORY,"oversize")
	fresh_hash=encoded.sha256_text()
	var primary_stage: String=store.path+".fresh-"+transaction+".primary"
	var backup_stage: String=store.path+".fresh-"+transaction+".backup"
	for stage: String in [primary_stage,backup_stage]:
		if FileAccess.file_exists(stage): return _fail(ERR_ALREADY_EXISTS,"write_failed")
		error=_write_file(stage,encoded)
		if error!=OK: return _fail(error,"write_failed")
		if store._read(stage,"recovery").status!="ok" or FileAccess.get_sha256(stage)!=fresh_hash: return _fail(ERR_FILE_CORRUPT,"validation_failed")
	for index in originals.size():
		var source: String=store.path+SUFFIXES[index]
		if originals[index].present:
			if not _matches(source,originals[index]): return _fail(ERR_FILE_CORRUPT,"checksum_invalid")
		elif FileAccess.file_exists(source): return _fail(ERR_FILE_ALREADY_IN_USE,"write_failed")
	error=_journal("pending")
	if error!=OK: return _fail(error,"write_failed")
	error=_rename_file(primary_stage,store.path)
	if error!=OK: return _after_touch_failure(error,"rename_failed")
	error=_rename_file(backup_stage,store.path+".bak")
	if error!=OK: return _after_touch_failure(error,"rename_failed")
	for target: String in [store.path,store.path+".bak"]:
		if store._read(target,"recovery").status!="ok" or FileAccess.get_sha256(target)!=fresh_hash:
			return _after_touch_failure(ERR_FILE_CORRUPT,"validation_failed")
	error=_journal("complete")
	if error!=OK: return _after_touch_failure(error,"write_failed")
	store.blocked=false
	store.last_diagnostic=store._diagnostic("none","commit",OK,store.VERSION,encoded.to_utf8_buffer().size())
	return _result(true,OK,"none")
