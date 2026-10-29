extends RefCounted
## Bounded JSON storage; diagnostics contain metadata only, never paths or payloads.
const VERSION := 4
const MAX_BYTES := 2 * 1024 * 1024
var path: String
var validator: Callable
var blocked := false
var last_diagnostic: Dictionary={}
func _init(file_path: String,validate: Callable) -> void:
	path=file_path
	validator=validate
	last_diagnostic=_diagnostic("none","read_primary")
func _diagnostic(reason: String,stage: String,error: int=OK,schema: float=-1,bytes: int=0) -> Dictionary:
	return {"reason":reason,"stage":stage,"error":error,"encountered_schema":schema,"required_schema":VERSION,"bytes":bytes}
func _result(status: String,reason: String,stage: String,error: int=OK,schema: float=-1,bytes: int=0) -> Dictionary:
	return {"status":status,"diagnostic":_diagnostic(reason,stage,error,schema,bytes)}
func _read(file_path: String,stage: String="read_primary") -> Dictionary:
	if not FileAccess.file_exists(file_path): return _result("missing","missing",stage)
	var file := FileAccess.open(file_path,FileAccess.READ)
	if file==null: return _result("invalid","open_failed",stage,FileAccess.get_open_error())
	var bytes := file.get_length()
	if bytes>MAX_BYTES:
		file.close()
		return _result("invalid","oversize",stage,OK,-1,bytes)
	var text := file.get_as_text()
	var read_error := file.get_error()
	file.close()
	if read_error!=OK: return _result("invalid","open_failed",stage,read_error,-1,bytes)
	var parser := JSON.new()
	if parser.parse(text)!=OK: return _result("invalid","json_invalid",stage,OK,-1,bytes)
	var envelope: Variant=parser.data
	if not envelope is Dictionary: return _result("invalid","payload_invalid",stage,OK,-1,bytes)
	var schema: Variant=envelope.get("version")
	if not (schema is int or schema is float): return _result("invalid","payload_invalid",stage,OK,-1,bytes)
	if schema!=VERSION: return _result("unsupported","unsupported_schema",stage,OK,float(schema),bytes)
	var payload: Variant=envelope.get("payload")
	if not payload is String or payload.sha256_text()!=envelope.get("sha256"):
		return _result("invalid","checksum_invalid",stage,OK,float(schema),bytes)
	if parser.parse(payload)!=OK: return _result("invalid","payload_invalid",stage,OK,float(schema),bytes)
	var data: Variant=parser.data
	if not data is Dictionary or not validator.call(data):
		return _result("invalid","validation_failed",stage,OK,float(schema),bytes)
	var result := _result("ok","none",stage,OK,float(schema),bytes)
	result.data=data
	return result
func read_save() -> Dictionary:
	blocked=false
	if not preload("res://scripts/persistence/save_recovery.gd").paths_safe(path):
		blocked=true
		last_diagnostic=_diagnostic("open_failed","read_primary",ERR_UNAUTHORIZED)
		return {"status":"invalid","diagnostic":last_diagnostic.duplicate()}
	if preload("res://scripts/persistence/save_recovery.gd").journal_state(path).pending:
		blocked=true
		last_diagnostic=_diagnostic("recovery_pending","recovery")
		return {"status":"recovery_pending","diagnostic":last_diagnostic.duplicate()}
	var primary := _read(path)
	if primary.status in ["ok","unsupported"]:
		blocked=primary.status=="unsupported"
		last_diagnostic=primary.diagnostic.duplicate()
		return primary
	var backup := _read(path+".bak","read_backup")
	if backup.status=="ok":
		backup.status="recovered"
		last_diagnostic=primary.diagnostic.duplicate()
		backup.diagnostic=last_diagnostic.duplicate()
		return backup
	blocked=primary.status!="missing" or backup.status!="missing"
	last_diagnostic=(backup.diagnostic if primary.status=="missing" and backup.status!="missing" else primary.diagnostic).duplicate()
	return {"status":"invalid" if blocked else "missing","diagnostic":last_diagnostic.duplicate()}
func _failure(reason: String,stage: String,error: int,schema: float=-1,bytes: int=0) -> Error:
	last_diagnostic=_diagnostic(reason,stage,error,schema,bytes)
	return error as Error
func write_save(data: Dictionary) -> Error:
	if not preload("res://scripts/persistence/save_recovery.gd").paths_safe(path):
		blocked=true
		return _failure("write_failed","write_temp",ERR_UNAUTHORIZED)
	if preload("res://scripts/persistence/save_recovery.gd").journal_state(path).pending:
		blocked=true
		last_diagnostic=_diagnostic("recovery_pending","recovery")
		return ERR_BUSY
	if blocked: return ERR_INVALID_DATA
	var existing := _read(path)
	if existing.status=="unsupported":
		blocked=true
		last_diagnostic=existing.diagnostic.duplicate()
		return ERR_INVALID_DATA
	if not validator.call(data):
		last_diagnostic=_diagnostic("validation_failed","validate_capture")
		return ERR_INVALID_DATA
	var payload := JSON.stringify(data)
	var encoded := JSON.stringify({"version":VERSION,"payload":payload,"sha256":payload.sha256_text()})
	var bytes := encoded.to_utf8_buffer().size()
	if bytes>MAX_BYTES: return _failure("oversize","write_temp",ERR_OUT_OF_MEMORY,VERSION,bytes)
	var directory := ProjectSettings.globalize_path(path.get_base_dir())
	var error := DirAccess.make_dir_recursive_absolute(directory)
	if error!=OK: return _failure("write_failed","write_temp",error,VERSION,bytes)
	var temp := path+".tmp"
	var file := FileAccess.open(temp,FileAccess.WRITE)
	if file==null: return _failure("write_failed","write_temp",FileAccess.get_open_error(),VERSION,bytes)
	file.store_string(encoded)
	file.flush()
	error=file.get_error()
	file.close()
	if error!=OK: return _failure("write_failed","write_temp",error,VERSION,bytes)
	var staged := _read(temp,"verify_temp")
	if staged.status!="ok":
		last_diagnostic=staged.diagnostic.duplicate()
		return ERR_FILE_CANT_WRITE
	var previous := _read(path)
	if previous.status=="unsupported":
		blocked=true
		last_diagnostic=previous.diagnostic.duplicate()
		return ERR_INVALID_DATA
	if previous.status=="ok":
		error=DirAccess.copy_absolute(path,path+".bak.tmp")
		if error!=OK: return _failure("write_failed","backup",error,VERSION,bytes)
		var copied := _read(path+".bak.tmp","backup")
		if copied.status!="ok":
			last_diagnostic=copied.diagnostic.duplicate()
			return ERR_FILE_CANT_WRITE
		error=DirAccess.rename_absolute(path+".bak.tmp",path+".bak")
		if error!=OK: return _failure("rename_failed","backup",error,VERSION,bytes)
	elif _read(path+".bak","read_backup").status!="ok":
		error=DirAccess.copy_absolute(temp,path+".bak.tmp")
		if error!=OK: return _failure("write_failed","backup",error,VERSION,bytes)
		var copied := _read(path+".bak.tmp","backup")
		if copied.status!="ok":
			last_diagnostic=copied.diagnostic.duplicate()
			return ERR_FILE_CANT_WRITE
		error=DirAccess.rename_absolute(path+".bak.tmp",path+".bak")
		if error!=OK: return _failure("rename_failed","backup",error,VERSION,bytes)
	error=DirAccess.rename_absolute(temp,path)
	if error!=OK: return _failure("rename_failed","commit",error,VERSION,bytes)
	last_diagnostic=_diagnostic("none","commit",OK,VERSION,bytes)
	return OK
func start_fresh_with_backup(fresh: Dictionary) -> Dictionary:
	return preload("res://scripts/persistence/save_recovery.gd").new(self).run(fresh)
