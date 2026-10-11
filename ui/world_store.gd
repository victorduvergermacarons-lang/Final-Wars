class_name WorldStore
extends RefCounted
## The host's saved world state (one-time events) in user://world.json.

const DEFAULT_PATH := "user://world.json"

var path: String


func _init(p_path: String = DEFAULT_PATH) -> void:
	path = p_path


func load_flags() -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		return {}
	var parsed = json.data
	if typeof(parsed) != TYPE_DICTIONARY or typeof(parsed.get("flags")) != TYPE_DICTIONARY:
		return {}
	return parsed.flags


func save(flags: Dictionary) -> Error:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify({"version": 1, "flags": flags}, "\t"))
	return OK
