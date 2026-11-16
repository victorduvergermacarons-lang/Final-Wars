extends Node
## One-off (2026-11-16): writes every hand-made map once through the map editor's
## saver (Godot's resource writer), so later saves from the editor only show real
## changes. The content is unchanged (test_every_map_saves_and_loads_back_the_same).
##   godot --headless --path . res://tools/once/resave_zones.tscn


func _ready() -> void:
	for z: ZoneDef in MapEditor.editable_zones():
		var ts: TilesetData = ContentDB.tilesets[z.tileset]
		var edit := ZoneEdit.new(ZoneEdit.load_working(z.resource_path, ts), ts)
		var saver := ZoneSaver.new()
		var err := saver.save(edit, z.resource_path)
		print("%s: %s, wrote %s" % [z.id, error_string(err), ", ".join(saver.written)])
	get_tree().quit()
