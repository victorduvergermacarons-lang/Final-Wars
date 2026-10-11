class_name CharacterStore
extends RefCounted
## Saved characters on this computer: one JSON file per character in
## user://characters/ (folder overridable for tests).

const DEFAULT_DIR := "user://characters"

var dir: String


func _init(p_dir: String = DEFAULT_DIR) -> void:
	dir = p_dir
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))


## Character names found on disk, sorted.
func list() -> PackedStringArray:
	var out: PackedStringArray = []
	for file in DirAccess.get_files_at(dir):
		if file.ends_with(".json"):
			var data := load_character(file.trim_suffix(".json"), true)
			if not data.is_empty():
				out.append(str(data.get("name", file.trim_suffix(".json"))))
	out.sort()
	return out


func exists(char_name: String) -> bool:
	return FileAccess.file_exists(_path(char_name))


func save(data: Dictionary) -> Error:
	var file := FileAccess.open(_path(str(data.get("name", ""))), FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data, "\t"))
	return OK


## The saved data, or {} if missing or unreadable. `by_file` treats the argument
## as a file stem instead of a character name.
func load_character(char_name: String, by_file: bool = false) -> Dictionary:
	var path := dir.path_join(char_name + ".json") if by_file else _path(char_name)
	if not FileAccess.file_exists(path):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func delete(char_name: String) -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_path(char_name)))


## File name from a character name: letters, digits, - and _ only.
static func slug(char_name: String) -> String:
	var out := ""
	for c in char_name.to_lower():
		if (c >= "a" and c <= "z") or (c >= "0" and c <= "9") or c == "-" or c == "_":
			out += c
		elif c == " ":
			out += "_"
	return out if not out.is_empty() else "character"


func _path(char_name: String) -> String:
	return dir.path_join(slug(char_name) + ".json")
