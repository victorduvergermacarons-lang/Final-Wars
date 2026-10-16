class_name TilesetData
extends RefCounted
## One isometric tileset: a folder under res://assets/tiles/ holding the tile
## images and a tileset.json catalog. Adding a tileset needs only that folder.
## This is plain data (no textures), so the simulation can read walkability and
## sight from it; the view loads the images.
##
## Catalog fields:
##   id, name, file_pattern ("tile_%03d.png"), cell_size [w, h] in art pixels,
##   top_y (art y of a block's top corner), level_height (art px per height level),
##   tiles: [{id, name, category, kind, walkable, blocks_sight, ...}],
##   animations: {name: {frames: [ids], fps}},
##   terrains: {name: {tiles: [id or [id, weight]], fill: terrain under it}}.

const ROOT := "res://assets/tiles"
const CATALOG := "tileset.json"
const CATEGORIES := ["ground", "path", "foliage", "prop", "rock", "water", "effect"]
## block: a full block on its cell. prop: drawn on top of the block beneath it.
## surface: a flat top without sides. overlay: a small sprite drawn over a tile.
const KINDS := ["block", "prop", "surface", "overlay"]

var id: StringName = &""
var display_name := ""
var dir := ""
var file_pattern := "tile_%03d.png"
var cell_size := Vector2i(32, 32)
var top_y := 8
var level_height := 8
var tiles := {} # int id -> Dictionary
var animations := {} # name -> {"frames": Array[int], "fps": float}
var terrains := {} # name -> {"tiles": Array[int], "weights": Array[float], "fill": String}
## Problems found while loading (see validate()).
var load_errors: PackedStringArray = []


## Every tileset folder under ROOT, by id.
static func load_all(root: String = ROOT) -> Dictionary:
	var out := {}
	for sub in DirAccess.get_directories_at(root):
		var path := root.path_join(sub).path_join(CATALOG)
		if FileAccess.file_exists(path):
			var t := load_file(path)
			if t.id != &"":
				out[t.id] = t
	return out


static func load_file(path: String) -> TilesetData:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	var t := TilesetData.new()
	if typeof(parsed) != TYPE_DICTIONARY:
		t.load_errors.append("%s: not a JSON object" % path)
		return t
	t.load_dict(parsed, path.get_base_dir())
	return t


func load_dict(d: Dictionary, folder: String) -> void:
	dir = folder
	id = StringName(str(d.get("id", "")))
	display_name = str(d.get("name", id))
	file_pattern = str(d.get("file_pattern", file_pattern))
	var cs: Array = d.get("cell_size", [32, 32])
	cell_size = Vector2i(int(cs[0]), int(cs[1]))
	top_y = int(d.get("top_y", top_y))
	level_height = int(d.get("level_height", level_height))
	for entry in d.get("tiles", []):
		var tid := int(entry.get("id", -1))
		if tiles.has(tid):
			load_errors.append("%s: tile %d listed twice" % [id, tid])
		tiles[tid] = entry
	for name in d.get("animations", {}):
		var a: Dictionary = d.animations[name]
		var frames: Array[int] = []
		for f in a.get("frames", []):
			frames.append(int(f))
		animations[name] = {"frames": frames, "fps": float(a.get("fps", 6.0))}
	for name in d.get("terrains", {}):
		var tr: Dictionary = d.terrains[name]
		var ids: Array[int] = []
		var weights: Array[float] = []
		for e in tr.get("tiles", []):
			if e is Array:
				ids.append(int(e[0]))
				weights.append(float(e[1]))
			else:
				ids.append(int(e))
				weights.append(1.0)
		terrains[name] = {"tiles": ids, "weights": weights, "fill": str(tr.get("fill", ""))}


func tile(tile_id: int) -> Dictionary:
	return tiles.get(tile_id, {})


func tile_path(tile_id: int) -> String:
	return dir.path_join(file_pattern % tile_id)


func is_walkable(tile_id: int) -> bool:
	return bool(tile(tile_id).get("walkable", false))


func blocks_sight(tile_id: int) -> bool:
	return bool(tile(tile_id).get("blocks_sight", false))


## Problems in the catalog, as readable messages (empty = fine).
func validate() -> PackedStringArray:
	var errors := load_errors.duplicate()
	if id == &"":
		errors.append("%s: missing id" % dir)
	for tid in tiles:
		var t: Dictionary = tiles[tid]
		if tid < 0:
			errors.append("%s: tile without an id" % id)
			continue
		for key in ["name", "category", "kind", "walkable", "blocks_sight"]:
			if not t.has(key):
				errors.append("%s: tile %d has no %s" % [id, tid, key])
		if not CATEGORIES.has(t.get("category", "")):
			errors.append("%s: tile %d has unknown category '%s'" % [id, tid, t.get("category", "")])
		if not KINDS.has(t.get("kind", "")):
			errors.append("%s: tile %d has unknown kind '%s'" % [id, tid, t.get("kind", "")])
		if not FileAccess.file_exists(tile_path(tid)) and not ResourceLoader.exists(tile_path(tid)):
			errors.append("%s: tile %d image missing: %s" % [id, tid, tile_path(tid)])
	for name in animations:
		for f in animations[name].frames:
			if not tiles.has(f):
				errors.append("%s: animation %s uses unknown tile %d" % [id, name, f])
	for name in terrains:
		var tr: Dictionary = terrains[name]
		if tr.tiles.is_empty():
			errors.append("%s: terrain %s has no tiles" % [id, name])
		for i in tr.tiles.size():
			var tid: int = tr.tiles[i]
			if not tiles.has(tid):
				errors.append("%s: terrain %s uses unknown tile %d" % [id, name, tid])
			elif tiles[tid].get("kind") != "block":
				errors.append("%s: terrain %s uses tile %d, which is not a block" % [id, name, tid])
			if tr.weights[i] <= 0.0:
				errors.append("%s: terrain %s gives tile %d a weight of %s" % [id, name, tid, tr.weights[i]])
		var seen := {name: true}
		var fill: String = tr.fill
		while fill != "":
			if not terrains.has(fill):
				errors.append("%s: terrain %s fills with unknown terrain %s" % [id, name, fill])
				break
			if seen.has(fill):
				errors.append("%s: terrain %s has a fill loop" % [id, name])
				break
			seen[fill] = true
			fill = terrains[fill].fill
	return errors
