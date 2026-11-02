extends SceneTree
## Runs inside an exported data pack (godot --main-pack <pck> -s <this file>):
## loads the game's content the way the exported game does (the ContentDB
## autoload) and prints one line per zone, then EXPORT_PROBE_DONE.


func _process(_delta: float) -> bool:
	var db = root.get_node_or_null("ContentDB")
	if db == null:
		print("EXPORT_PROBE_FAIL no ContentDB")
		return true
	for id in db.zones:
		var z = db.zones[id]
		var errors: PackedStringArray = z.validate()
		print("EXPORT_PROBE_ZONE %s heights=%d walk=%d errors=%s" % [id, z.height_rows.size(), z.walk_rows.size(), "|".join(errors)])
	print("EXPORT_PROBE_TILESETS %d" % db.tilesets.size())
	print("EXPORT_PROBE_ABILITIES %d" % db.abilities.size())
	print("EXPORT_PROBE_DONE")
	return true
