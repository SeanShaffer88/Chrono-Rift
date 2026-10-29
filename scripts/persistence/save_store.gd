extends RefCounted
## JSON-only, bounded, checksummed storage. Temp writes and atomic replacement;
## a validated previous primary becomes the backup before primary replacement.
const VERSION := 4
const MAX_BYTES := 2 * 1024 * 1024
var path: String
var validator: Callable
var blocked := false

func _init(file_path: String, validate: Callable) -> void:
	path = file_path
	validator = validate

func _read(file_path: String) -> Dictionary:
	if not FileAccess.file_exists(file_path):
		return {"status": "missing"}
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null or file.get_length() > MAX_BYTES:
		return {"status": "invalid"}
	var text := file.get_as_text()
	file.close()
	var parser := JSON.new()
	if parser.parse(text) != OK:
		return {"status": "invalid"}
	var envelope: Variant = parser.data
	if not envelope is Dictionary:
		return {"status": "invalid"}
	# Unknown versions must never be replaced by this older game.
	if not (envelope.get("version") is int or envelope.get("version") is float):
		return {"status": "invalid"}
	if envelope.get("version") != VERSION:
		return {"status": "unsupported"}
	var payload: Variant = envelope.get("payload")
	if not payload is String or payload.sha256_text() != envelope.get("sha256"):
		return {"status": "invalid"}
	if parser.parse(payload) != OK:
		return {"status": "invalid"}
	var data: Variant = parser.data
	if not data is Dictionary or not validator.call(data):
		return {"status": "invalid"}
	return {"status": "ok", "data": data}

func read_save() -> Dictionary:
	blocked = false
	var primary := _read(path)
	if primary.status == "ok":
		return primary
	if primary.status == "unsupported":
		blocked = true
		return primary
	var backup := _read(path + ".bak")
	if backup.status == "ok":
		backup.status = "recovered"
		return backup
	blocked = primary.status != "missing" or backup.status != "missing"
	return {"status": "invalid" if blocked else "missing"}

func write_save(data: Dictionary) -> Error:
	if blocked or not validator.call(data):
		return ERR_INVALID_DATA
	var payload := JSON.stringify(data)
	var encoded := JSON.stringify({"version": VERSION, "payload": payload, "sha256": payload.sha256_text()})
	if encoded.to_utf8_buffer().size() > MAX_BYTES:
		return ERR_OUT_OF_MEMORY
	var directory := ProjectSettings.globalize_path(path.get_base_dir())
	var error := DirAccess.make_dir_recursive_absolute(directory)
	if error != OK:
		return error
	var temp := path + ".tmp"
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(encoded)
	file.flush()
	error = file.get_error()
	file.close()
	if error != OK or _read(temp).status != "ok":
		return ERR_FILE_CANT_WRITE
	var previous := _read(path)
	if previous.status == "unsupported":
		blocked = true
		return ERR_INVALID_DATA
	if previous.status == "ok":
		error = DirAccess.copy_absolute(path, path + ".bak.tmp")
		if error != OK or _read(path + ".bak.tmp").status != "ok":
			return ERR_FILE_CANT_WRITE
		error = DirAccess.rename_absolute(path + ".bak.tmp", path + ".bak")
		if error != OK:
			return error
	elif _read(path + ".bak").status != "ok":
		error = DirAccess.copy_absolute(temp, path + ".bak.tmp")
		if error != OK or _read(path + ".bak.tmp").status != "ok":
			return ERR_FILE_CANT_WRITE
		error = DirAccess.rename_absolute(path + ".bak.tmp", path + ".bak")
		if error != OK: return error
	# An invalid primary is never copied over a valid recovery backup.
	return DirAccess.rename_absolute(temp, path)
