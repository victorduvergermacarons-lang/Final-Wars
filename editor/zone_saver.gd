class_name ZoneSaver
extends RefCounted
## Writes the map editor's zone with Godot's resource writer, and every other file
## the change reaches:
## - the maps on the other side of its edges (each link written on both maps),
## - doors in other maps that lead into it, quest places in it (reach, escort,
##   investigate) and its boss encounter's tiles, when its coordinates moved (rows or
##   columns added or removed on the north-west / north-east sides),
## - other maps a person was moved away from (each person stands in one place).
## Every file is loaded fresh from disk, changed and written back; then the game's
## loaded copies are refreshed, so Play uses the new maps at once.

const ZONES_DIR := "res://content/zones/"
const QUESTS_DIR := "res://content/quests/"

## Tests write under this folder instead of res:// (e.g. "user://editor_test/"), and
## read back from there what was already written.
var redirect := ""
## Paths written by the last save, and plain notes on what else it changed.
var written: PackedStringArray = []
var notes: PackedStringArray = []


## Saves `edit`'s zone to `path` and its consequences. Returns OK or the first error.
func save(edit: ZoneEdit, path: String) -> Error:
	written = []
	notes = []
	var z := edit.zone
	var by: Vector2i = edit.shift - edit.saved_shift
	edit.tidy_legends()
	var err := _write(z, path)
	if err != OK:
		return err
	var my_npcs := {}
	for n in z.npcs:
		my_npcs[n.npc.id] = true
	# The boss encounter's tiles.
	if by != Vector2i.ZERO and z.encounter != null and z.encounter.resource_path != "":
		var enc: Resource = _load(z.encounter.resource_path)
		enc.victory_tile += by
		err = _write(enc, z.encounter.resource_path)
		if err != OK:
			return err
		notes.append("Moved the boss fight's victory spot with the map.")
	# Quest places in this map.
	if by != Vector2i.ZERO:
		for file in _files(QUESTS_DIR):
			var q: QuestDef = _load(QUESTS_DIR + file)
			var changed := false
			for o in q.objectives:
				if o.zone != z.id:
					continue
				o.tile += by
				for i in o.path.size():
					o.path[i] += by
				for i in o.spots.size():
					o.spots[i] += by
				changed = true
			if changed:
				err = _write(q, QUESTS_DIR + file)
				if err != OK:
					return err
				notes.append("Moved the places of quest \"%s\" with the map." % q.title)
	# Other maps: edges on both sides, doors into this map, people moved here.
	for file in _files(ZONES_DIR):
		var other_path := ZONES_DIR + file
		if other_path == path:
			continue
		var other: ZoneDef = _load(other_path)
		if other == null or other.id == z.id:
			continue
		var changed := _sync_edges(z, other)
		if by != Vector2i.ZERO:
			for e in other.exits:
				if e.to_zone == z.id:
					e.to_tile += by
					changed = true
		for i in range(other.npcs.size() - 1, -1, -1):
			var n: NpcSpawn = other.npcs[i]
			if n != null and n.npc != null and my_npcs.has(n.npc.id):
				other.npcs.remove_at(i)
				notes.append("%s moved here from %s." % [n.npc.display_name, other.display_name])
				changed = true
		if changed:
			err = _write(other, other_path)
			if err != OK:
				return err
	edit.saved_shift = edit.shift
	edit.dirty = false
	refresh_game(written)
	return OK


## Makes `other`'s edges toward `z` mirror `z`'s edges toward it. True if changed.
static func _sync_edges(z: ZoneDef, other: ZoneDef) -> bool:
	var want := {}
	for e in z.edges:
		if e.to_zone == other.id:
			want[var_to_str([-e.side, -e.offset])] = [-e.side, -e.offset]
	var have := {}
	for e in other.edges:
		if e.to_zone == z.id:
			have[var_to_str([e.side, e.offset])] = true
	var same := want.size() == have.size()
	for k in want:
		same = same and have.has(k)
	if same:
		return false
	for i in range(other.edges.size() - 1, -1, -1):
		if other.edges[i].to_zone == z.id:
			other.edges.remove_at(i)
	for w in want.values():
		var e := ZoneEdge.new()
		e.side = w[0]
		e.to_zone = z.id
		e.offset = w[1]
		other.edges.append(e)
	return true


func _target(path: String) -> String:
	return path if redirect == "" else redirect.path_join(path.trim_prefix("res://"))


func _write(res: Resource, path: String) -> Error:
	var target := _target(path)
	DirAccess.make_dir_recursive_absolute(target.get_base_dir())
	var err := ResourceSaver.save(res, target)
	if err == OK and not written.has(path):
		written.append(path)
	return err


## A fresh copy of the file (the redirected copy if this save session wrote one).
func _load(path: String) -> Resource:
	var from := _target(path)
	if not FileAccess.file_exists(from):
		from = path
	return ResourceLoader.load(from, "", ResourceLoader.CACHE_MODE_IGNORE)


func _files(dir: String) -> PackedStringArray:
	var out: PackedStringArray = []
	for f in ResourceLoader.list_directory(dir):
		if f.ends_with(".tres"):
			out.append(f)
	return out


## Puts freshly loaded copies of the written files into the game's content.
func refresh_game(paths: PackedStringArray) -> void:
	# Encounters first: the zones that use them pick them up from the cache.
	var order := Array(paths)
	order.sort_custom(func(a, b): return _rank(a) < _rank(b))
	for path in order:
		var res: Resource = ResourceLoader.load(_target(path), "", ResourceLoader.CACHE_MODE_IGNORE)
		if res == null:
			continue
		if redirect == "":
			res.take_over_path(path)
		if res is ZoneDef:
			if res.has_terrain() and ContentDB.tilesets.has(res.tileset):
				res.bake_walkability(ContentDB.tilesets[res.tileset])
			ContentDB.zones[res.id] = res
		elif res is QuestDef:
			ContentDB.quests[res.id] = res
	ContentDB.link_tree_items()


static func _rank(path: String) -> int:
	if path.begins_with(ZONES_DIR):
		return 2
	if path.begins_with(QUESTS_DIR):
		return 1
	return 0
