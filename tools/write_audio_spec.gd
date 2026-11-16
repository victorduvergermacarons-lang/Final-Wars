class_name AudioSpecWriter
extends SceneTree
## Rewrites the sound key list in AUDIO_SPEC.md from the game's content (the same
## SoundCatalog the game plays from), marking which files exist yet.
##   godot --headless --path . -s res://tools/write_audio_spec.gd
## Only the part between the two "sound keys" markers is replaced; the rest of the
## file is written by hand.

const SPEC := "res://AUDIO_SPEC.md"
const START := "<!-- sound keys start: written by tools/write_audio_spec.gd -->"
const END := "<!-- sound keys end -->"

const GROUPS := [
	["ui", "Interface (audio/sfx/ui, UI bus)"],
	["world", "World events (audio/sfx/world)"],
	["footstep", "Footsteps (audio/sfx/footsteps)"],
	["weapon", "Weapons: Sword, Bow and Hammer arts (audio/sfx/weapons)"],
	["fire", "Fire (audio/sfx/fire)"],
	["water", "Water (audio/sfx/water)"],
	["earth", "Earth (audio/sfx/earth)"],
	["air", "Air (audio/sfx/air)"],
	["creature", "Creatures (audio/sfx/creatures)"],
	["ambience", "Ambience loops (audio/ambience, OGG, Ambience bus)"],
]


func _init() -> void:
	await process_frame # autoloads (ContentDB, Audio) are ready
	var result := write(root.get_node("ContentDB"), root.get_node("Audio").config)
	if result.error != OK:
		printerr("ERROR: %s needs the lines\n%s\n%s" % [SPEC, START, END])
		quit(1)
		return
	print("Wrote %d sound keys to %s (%d without a file yet)." % [result.keys, SPEC, result.missing])
	quit()


## Rewrites the key list from `content` (ContentDB); also used by the map editor
## when it adds a map (a new ambience key). Returns {"error", "keys", "missing"}.
static func write(content, config: AudioConfig, spec_path := SPEC) -> Dictionary:
	var text := FileAccess.get_file_as_string(spec_path)
	var a := text.find(START)
	var b := text.find(END)
	if a == -1 or b == -1 or b < a:
		return {"error": ERR_PARSE_ERROR, "keys": 0, "missing": 0}
	var keys: Dictionary = SoundCatalog.new(content).keys()
	var body := _list(keys, config)
	var out := text.substr(0, a + START.length()) + "\n" + body + text.substr(b)
	var f := FileAccess.open(spec_path, FileAccess.WRITE)
	if f == null:
		return {"error": FileAccess.get_open_error(), "keys": 0, "missing": 0}
	f.store_string(out)
	f.close()
	var missing := 0
	for k in keys:
		if not _exists(config.file_for(k)):
			missing += 1
	return {"error": OK, "keys": keys.size(), "missing": missing}


static func _exists(path: String) -> bool:
	if ResourceLoader.exists(path):
		return true
	return ResourceLoader.exists("%s_1.%s" % [path.get_basename(), path.get_extension()])


static func _list(keys: Dictionary, config: AudioConfig) -> String:
	var total := 0
	var have := 0
	var sections := ""
	for g in GROUPS:
		var rows := ""
		for k in keys:
			if String(k).get_slice("_", 0) != g[0]:
				continue
			var path := config.file_for(k)
			var ok := _exists(path)
			total += 1
			have += 1 if ok else 0
			rows += "| `%s` | %s | %s |\n" % [k, keys[k], "yes" if ok else "**missing**"]
		if rows != "":
			sections += "\n### %s\n\n| Key | Plays when | File |\n|-----|-----------|------|\n%s" % [g[1], rows]
	return "\n%d keys, %d with a file, %d missing. File = `audio/<folder>/<key>.wav` (`.ogg` for ambience).\n%s\n" \
			% [total, have, total - have, sections]
