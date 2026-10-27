extends SceneTree
## One-off companion of make_act1_zones.py: bakes walk_rows and sight_rows of the
## generated zone files from the tileset (exactly as ContentDB does at load) and
## writes them back into the files, so the copies on disk match.
## Usage: godot --headless --path . -s res://tools/once/bake_zone_rows.gd

const ZONES := ["town", "crossing", "deepcut_road", "deepcut", "windsteppe", "tidereach_shore"]


func _init() -> void:
	var tilesets := TilesetData.load_all()
	for id in ZONES:
		var path := "res://content/zones/%s.tres" % id
		var zone: ZoneDef = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
		zone.bake_walkability(tilesets[zone.tileset])
		var text := FileAccess.get_file_as_string(path)
		text = _replace_rows(text, "walk_rows", zone.walk_rows)
		text = _replace_rows(text, "sight_rows", zone.sight_rows)
		var f := FileAccess.open(path, FileAccess.WRITE)
		f.store_string(text)
		f.close()
		print("baked ", id)
	quit()


static func _replace_rows(text: String, key: String, rows: PackedStringArray) -> String:
	var quoted := PackedStringArray()
	for r in rows:
		quoted.append("\"%s\"" % r)
	var re := RegEx.new()
	re.compile("(?m)^%s = PackedStringArray\\(.*\\)$" % key)
	return re.sub(text, "%s = PackedStringArray(%s)" % [key, ", ".join(quoted)])
