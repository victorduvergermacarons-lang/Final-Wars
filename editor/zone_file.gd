class_name ZoneFile
extends RefCounted
## Writes the map editor's layers back into a zone's .tres file. Only the rows
## and legends are replaced, in place; every other line (spawns, NPCs, decor,
## edges, settings) is kept exactly as it was.

const ROW_KEYS := ["height_rows", "walk_rows", "terrain_rows", "prop_rows", "sight_rows"]
const LEGEND_KEYS := ["terrain_legend", "prop_legend"]


## Writes `zone`'s layers into the file at `path`. Returns OK or an error.
static func save(path: String, zone: ZoneDef) -> Error:
	if not FileAccess.file_exists(path):
		return ERR_FILE_NOT_FOUND
	var text := FileAccess.get_file_as_string(path)
	text = with_layers(text, zone)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(text)
	f.close()
	return OK


## `text` (a zone .tres) with `zone`'s rows and legends written in.
static func with_layers(text: String, zone: ZoneDef) -> String:
	for key in ROW_KEYS:
		text = _put(text, key, "%s = %s" % [key, rows_text(zone.get(key))], "(?m)^%s = PackedStringArray\\(.*\\)$" % key)
	for key in LEGEND_KEYS:
		text = _put(text, key, "%s = %s" % [key, legend_text(zone.get(key))], "(?ms)^%s = \\{.*?^\\}$|(?m)^%s = \\{\\}$" % [key, key])
	return text


## Replaces the line(s) `pattern` matches, or adds `line` at the end of the file
## (the [resource] section is last) when the key isn't there yet.
static func _put(text: String, key: String, line: String, pattern: String) -> String:
	var re := RegEx.new()
	re.compile(pattern)
	var m := re.search(text)
	if m != null:
		return text.substr(0, m.get_start()) + line + text.substr(m.get_end())
	if not text.ends_with("\n"):
		text += "\n"
	return text + line + "\n"


static func rows_text(rows: PackedStringArray) -> String:
	var quoted := PackedStringArray()
	for r in rows:
		quoted.append("\"%s\"" % r)
	return "PackedStringArray(%s)" % ", ".join(quoted)


static func legend_text(legend: Dictionary) -> String:
	if legend.is_empty():
		return "{}"
	var keys := legend.keys()
	keys.sort()
	var lines := PackedStringArray()
	for k in keys:
		lines.append("\"%s\": \"%s\"" % [k, legend[k]])
	return "{\n%s\n}" % ",\n".join(lines)
