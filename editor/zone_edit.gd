class_name ZoneEdit
extends RefCounted
## The map editor's model: paints a tiled zone's ground, heights and props; removes
## and adds tiles (the map's shape: holes are ZoneDef.NO_TILE; adding beyond the map
## grows it, and `trim` cuts empty rows and columns off its sides); places,
## moves and removes the things on it (enemies, people, hero spawns, graveyards,
## objects, landmarks, doors); resizes it; edits its map-edge links. Keeps the walk
## and sight rows (and a live GridModel, if given) in step, and undoes everything.
## Works on its own copy of the zone, loaded fresh from its file; nothing here draws
## or saves (ZoneSaver writes it, with the other files a change reaches).

enum Layer { TERRAIN, HEIGHT, PROP, SHAPE }

## Heights the editor paints: the digits of ZoneDef.HEIGHT_CHARS.
const MAX_HEIGHT := 9
## Characters a new legend entry may take, in order (props never use ".").
const LEGEND_CHARS := "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
const ROW_KEYS := ["height_rows", "walk_rows", "terrain_rows", "prop_rows", "sight_rows"]

## Kinds of things on a map -> the ZoneDef array that holds them.
const THING_ARRAYS := {
	"npc": "npcs", "enemy": "enemy_spawns", "decor": "decor", "landmark": "landmarks",
	"exit": "exits", "hero_spawn": "hero_spawns", "graveyard": "graveyards",
}
## Picking order when several things share a tile.
const THING_ORDER := ["npc", "enemy", "decor", "landmark", "exit", "hero_spawn", "graveyard"]
## Sides of a map, in grid directions, with the names shown on screen.
const SIDES := {
	Vector2i.UP: "North-east (top right)", Vector2i.RIGHT: "South-east (bottom right)",
	Vector2i.DOWN: "South-west (bottom left)", Vector2i.LEFT: "North-west (top left)",
}

var zone: ZoneDef
var tileset: TilesetData
## The live grid to keep in step (the editor's world view reads it); may be null.
## Things, resizes and links change more than tiles: `rebuild_needed` asks the
## editor to rebuild its view (and grid) from the zone.
var grid: GridModel
var rebuild_needed := false
## Changed since the last save.
var dirty := false
## How far the map's own coordinates have moved since its file was last written
## (rows or columns added or removed on the north-west / north-east sides). ZoneSaver
## shifts what other files say about this map by it, then resets it.
var shift := Vector2i.ZERO
## `shift` when the file was last written (undoing a resize after saving moves the
## other files back by the difference).
var saved_shift := Vector2i.ZERO

var _undo: Array = [] # tile strokes (Array of [layer, tile, old, new]) or {"before", "after"} states
var _redo: Array = []
var _stroke: Array = []
var _in_stroke := false
const UNDO_LIMIT := 200


func _init(p_zone: ZoneDef, p_tileset: TilesetData, p_grid: GridModel = null) -> void:
	zone = p_zone
	tileset = p_tileset
	grid = p_grid
	if zone.prop_rows.is_empty(): # props need a layer to paint on
		var empty := ".".repeat(zone.get_width())
		for y in zone.get_depth():
			zone.prop_rows.append(empty)


## A working copy of the zone at `path`, loaded fresh from its file (so nothing the
## game changed at load comes along, and nothing is shared with the game's copy),
## with its walk and sight rows baked.
static func load_working(path: String, ts: TilesetData) -> ZoneDef:
	var z: ZoneDef = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	if z == null:
		return null
	if ts != null and z.has_terrain():
		z.bake_walkability(ts)
	return z


## A working copy of a zone already loaded (tests; the editor loads from the file).
static func copy_of(source: ZoneDef) -> ZoneDef:
	if source.resource_path != "":
		return load_working(source.resource_path, ContentDB.tilesets.get(source.tileset))
	var z: ZoneDef = source.duplicate(true)
	for key in ROW_KEYS:
		z.set(key, PackedStringArray(Array(source.get(key))))
	return z


func width() -> int:
	return zone.get_width()


func depth() -> int:
	return zone.get_depth()


func size() -> Vector2i:
	return Vector2i(width(), depth())


func in_bounds(p: Vector2i) -> bool:
	return p.x >= 0 and p.y >= 0 and p.x < width() and p.y < depth()


## The tiles a square brush of `size` (1, 3, 5…) covers around `center`, inside
## the map's rectangle (all of them, beyond it too, with `clip` false).
func brush(center: Vector2i, brush_size: int, clip := true) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var r := maxi(brush_size, 1) / 2
	for y in range(center.y - r, center.y + r + 1):
		for x in range(center.x - r, center.x + r + 1):
			var p := Vector2i(x, y)
			if in_bounds(p) or not clip:
				out.append(p)
	return out


## Whether the map has a tile at `p` (inside it and not a hole in its shape).
func has_tile(p: Vector2i) -> bool:
	return zone.has_tile(p)


func tile_count() -> int:
	var n := 0
	for row in zone.height_rows:
		n += row.length() - row.count(ZoneDef.NO_TILE)
	return n


# --- Reading ------------------------------------------------------------------

func terrain_at(p: Vector2i) -> String:
	return zone.terrain_at(p)


func height_at(p: Vector2i) -> int:
	return ZoneDef.parse_height(zone.height_rows[p.y][p.x])


func prop_at(p: Vector2i) -> String:
	return zone.prop_at(p)


func is_walkable(p: Vector2i) -> bool:
	return in_bounds(p) and zone.walk_rows[p.y][p.x] == "."


## What the eyedropper copies: {"terrain", "height", "prop"} ("" and -1 at a hole).
func pick(p: Vector2i) -> Dictionary:
	return {"terrain": terrain_at(p), "height": height_at(p), "prop": prop_at(p)}


## Terrain kinds that can be painted (the tileset's, sorted).
func terrain_names() -> Array:
	var names := tileset.terrains.keys()
	names.sort()
	return names


## Prop groups that can be placed (the tileset's, sorted).
func prop_names() -> Array:
	var names := tileset.props.keys()
	names.sort()
	return names


# --- Painting -------------------------------------------------------------------

## Groups the changes until end_stroke into one undo step (a mouse drag).
func begin_stroke() -> void:
	_in_stroke = true
	_stroke = []


func end_stroke() -> void:
	_in_stroke = false
	_push(_stroke)
	_stroke = []


func paint_terrain(tiles: Array, terrain: String) -> Array[Vector2i]:
	if not tileset.terrains.has(terrain):
		return []
	return _paint(Layer.TERRAIN, tiles, func(_p): return terrain)


func paint_prop(tiles: Array, group: String) -> Array[Vector2i]:
	if group != "" and not tileset.props.has(group):
		return []
	return _paint(Layer.PROP, tiles, func(_p): return group)


func set_height(tiles: Array, h: int) -> Array[Vector2i]:
	var v := clampi(h, 0, MAX_HEIGHT)
	return _paint(Layer.HEIGHT, tiles, func(_p): return v)


## Raises (`delta` > 0) or lowers each tile by `delta` levels, from its own height.
func change_height(tiles: Array, delta: int) -> Array[Vector2i]:
	return _paint(Layer.HEIGHT, tiles, func(p): return clampi(height_at(p) + delta, 0, MAX_HEIGHT))


## Removes the map's tiles at `tiles` (they become holes: walls nothing enters).
## Refused (nothing changes) if no tile would be left. Things standing there stay
## (ZoneCheck lists them). Returns the tiles that changed.
func remove_tiles(tiles: Array) -> Array[Vector2i]:
	var gone := tiles.filter(func(p): return has_tile(p))
	if gone.size() >= tile_count():
		return []
	return _paint(Layer.SHAPE, gone, func(_p): return [])


## Adds tiles of `terrain` ground at height `h` where the map has none (holes, inside
## its rectangle; grow it first with grow_to_include for tiles beyond it).
func add_tiles(tiles: Array, terrain: String, h: int) -> Array[Vector2i]:
	if not tileset.terrains.has(terrain):
		return []
	var v := [terrain, clampi(h, 0, MAX_HEIGHT), ""]
	return _paint(Layer.SHAPE, tiles.filter(func(p): return in_bounds(p) and not has_tile(p)), func(_p): return v)


func _paint(layer: Layer, tiles: Array, value_of: Callable) -> Array[Vector2i]:
	var changed: Array[Vector2i] = []
	for p: Vector2i in tiles:
		if not in_bounds(p) or (layer != Layer.SHAPE and not has_tile(p)):
			continue
		var old: Variant = _read(layer, p)
		var new: Variant = value_of.call(p)
		if old == new:
			continue
		_write(layer, p, new)
		changed.append(p)
		var change := [layer, p, old, new]
		if _in_stroke:
			_stroke.append(change)
		else:
			_push([change])
	return _rebake(changed)


func _push(entry: Variant) -> void:
	if entry is Array and entry.is_empty():
		return
	_undo.append(entry)
	if _undo.size() > UNDO_LIMIT:
		_undo.pop_front()
	_redo.clear()
	dirty = true


func can_undo() -> bool:
	return not _undo.is_empty()


func can_redo() -> bool:
	return not _redo.is_empty()


## Takes back the last step; returns the tiles that changed (a change to things,
## size or links sets `rebuild_needed` instead).
func undo() -> Array[Vector2i]:
	if _undo.is_empty():
		return []
	var entry: Variant = _undo.pop_back()
	_redo.append(entry)
	dirty = true
	if entry is Dictionary:
		_restore(entry.before)
		return []
	var tiles: Array[Vector2i] = []
	for i in range(entry.size() - 1, -1, -1):
		var c: Array = entry[i]
		_write(c[0], c[1], c[2])
		tiles.append(c[1])
	return _rebake(tiles)


func redo() -> Array[Vector2i]:
	if _redo.is_empty():
		return []
	var entry: Variant = _redo.pop_back()
	_undo.append(entry)
	dirty = true
	if entry is Dictionary:
		_restore(entry.after)
		return []
	var tiles: Array[Vector2i] = []
	for c: Array in entry:
		_write(c[0], c[1], c[3])
		tiles.append(c[1])
	return _rebake(tiles)


func _read(layer: Layer, p: Vector2i) -> Variant:
	match layer:
		Layer.TERRAIN:
			return terrain_at(p)
		Layer.HEIGHT:
			return height_at(p)
		Layer.SHAPE: # [] for a hole
			return [terrain_at(p), height_at(p), prop_at(p)] if has_tile(p) else []
		_:
			return prop_at(p)


func _write(layer: Layer, p: Vector2i, value: Variant) -> void:
	match layer:
		Layer.TERRAIN:
			_set_char(zone.terrain_rows, p, _legend_char(zone.terrain_legend, str(value)))
		Layer.HEIGHT:
			_set_char(zone.height_rows, p, ZoneDef.HEIGHT_CHARS[int(value)])
		Layer.PROP:
			_set_char(zone.prop_rows, p, "." if str(value) == "" else _legend_char(zone.prop_legend, str(value)))
		Layer.SHAPE:
			var v: Array = value
			if v.is_empty():
				_set_char(zone.terrain_rows, p, ZoneDef.NO_TILE)
				_set_char(zone.height_rows, p, ZoneDef.NO_TILE)
				_set_char(zone.prop_rows, p, ".")
			else:
				_write(Layer.TERRAIN, p, v[0])
				_write(Layer.HEIGHT, p, v[1])
				_write(Layer.PROP, p, v[2])


static func _set_char(rows: PackedStringArray, p: Vector2i, c: String) -> void:
	var row := rows[p.y]
	rows[p.y] = row.substr(0, p.x) + c + row.substr(p.x + 1)


## The legend's character for `name`, adding one if it has none.
static func _legend_char(legend: Dictionary, name: String) -> String:
	for c in legend:
		if str(legend[c]) == name:
			return str(c)
	for c in LEGEND_CHARS:
		if not legend.has(c):
			legend[c] = name
			return c
	push_error("ZoneEdit: no free legend character for %s" % name)
	return "."


## Re-bakes walkability and sight of the changed tiles (into the zone's rows and
## the live grid). Returns `tiles`.
func _rebake(tiles: Array[Vector2i]) -> Array[Vector2i]:
	for p in tiles:
		var baked := zone.bake_tile(tileset, p)
		_set_char(zone.walk_rows, p, "." if baked.walkable else "#")
		_set_char(zone.sight_rows, p, "#" if baked.blocks_sight else ".")
		if baked.friction != 1.0:
			zone.friction_tiles[p] = baked.friction
		else:
			zone.friction_tiles.erase(p)
		if grid != null and not has_tile(p):
			grid.remove_tile(p)
		elif grid != null:
			grid.set_tile(p, height_at(p), baked.walkable)
			grid.set_blocks_sight(p, baked.blocks_sight)
			grid.set_friction(p, baked.friction)
	return tiles


## Drops legend entries no tile uses any more (before saving).
func tidy_legends() -> void:
	_tidy(zone.terrain_legend, zone.terrain_rows)
	_tidy(zone.prop_legend, zone.prop_rows)


static func _tidy(legend: Dictionary, rows: PackedStringArray) -> void:
	var used := {}
	for row in rows:
		for c in row:
			used[c] = true
	for c in legend.keys():
		if not used.has(c):
			legend.erase(c)


# --- Whole-map steps (things, size, links): undone by restoring a snapshot -----------

## Runs `change` as one undo step that may touch anything on the map.
func _change(change: Callable) -> Variant:
	var before := _state()
	var result: Variant = change.call()
	var after := _state()
	if not _same(before, after):
		_push({"before": before, "after": after})
		_settle()
	return result


## Everything a whole-map step can change, copied so later steps can't touch it.
func _state() -> Dictionary:
	var s := {"shift": shift, "terrain_legend": zone.terrain_legend.duplicate(),
			"prop_legend": zone.prop_legend.duplicate()}
	for key in ROW_KEYS:
		s[key] = PackedStringArray(Array(zone.get(key)))
	for kind in THING_ARRAYS:
		s[THING_ARRAYS[kind]] = _copy_list(zone.get(THING_ARRAYS[kind]))
	s.edges = _copy_list(zone.edges)
	return s


func _restore(s: Dictionary) -> void:
	shift = s.shift
	zone.terrain_legend = s.terrain_legend.duplicate()
	zone.prop_legend = s.prop_legend.duplicate()
	for key in ROW_KEYS:
		zone.set(key, PackedStringArray(Array(s[key])))
	for kind in THING_ARRAYS:
		zone.set(THING_ARRAYS[kind], _copy_list(s[THING_ARRAYS[kind]]))
	zone.edges = _copy_list(s.edges)
	_settle()


## After a whole-map step: re-bake every tile and ask for a rebuilt view.
func _settle() -> void:
	zone.forget_decor_cache()
	zone.bake_walkability(tileset)
	rebuild_needed = true


## A copy of a typed array of resources (or Vector2i), each element copied.
static func _copy_list(list: Array) -> Array:
	var out := list.duplicate()
	for i in out.size():
		if out[i] is Resource:
			out[i] = copy_thing(out[i])
	return out


static func copy_thing(res: Resource) -> Resource:
	var d: Resource = res.duplicate()
	for prop in ["patrol"]:
		if prop in d:
			d.set(prop, res.get(prop).duplicate())
	return d


static func _same(a: Dictionary, b: Dictionary) -> bool:
	return var_to_str(_plain(a)) == var_to_str(_plain(b))


## A whole zone as plain data (tests compare a saved map with the original).
static func _plain_zone(z: ZoneDef) -> Dictionary:
	return _plain(z)


## A state as plain data (resources as their properties) to compare two states.
static func _plain(v: Variant) -> Variant:
	if v is Resource:
		var d := {}
		for p in v.get_property_list():
			if p.usage & PROPERTY_USAGE_STORAGE and p.name != "script" and p.name != "resource_path" \
					and p.name != "resource_name" and p.name != "resource_local_to_scene" \
					and p.name != "resource_scene_unique_id":
				var x: Variant = v.get(p.name)
				# A resource of its own file by its path; one built into this file (a
				# sub-resource, "…tres::id", e.g. ZoneDef.cleared_exit) by its contents.
				var own_file: bool = x is Resource and x.resource_path != "" and not x.resource_path.contains("::")
				d[p.name] = x.resource_path if own_file else _plain(x)
		return d
	if v is Array:
		return v.map(func(x): return _plain(x))
	if v is Dictionary:
		var d := {}
		for k in v:
			d[k] = _plain(v[k])
		return d
	return v


# --- Things -----------------------------------------------------------------------

## A thing on the map: {"kind": "enemy" | "npc" | …, "index": its place in its array}.
static func ref(kind: String, index: int) -> Dictionary:
	return {"kind": kind, "index": index}


func things(kind: String) -> Array:
	return zone.get(THING_ARRAYS[kind])


func thing(r: Dictionary) -> Variant:
	var list := things(r.kind)
	return list[r.index] if r.index >= 0 and r.index < list.size() else null


func thing_tile(r: Dictionary) -> Vector2i:
	var t: Variant = thing(r)
	return t if t is Vector2i else t.tile


## Every thing on tile `p`, in picking order (people first).
func things_at(p: Vector2i) -> Array:
	var out := []
	for kind in THING_ORDER:
		var list := things(kind)
		for i in list.size():
			var t: Variant = list[i]
			if (t if t is Vector2i else t.tile) == p:
				out.append(ref(kind, i))
	return out


## Every thing on the map, in picking order.
func all_things() -> Array:
	var out := []
	for kind in THING_ORDER:
		for i in things(kind).size():
			out.append(ref(kind, i))
	return out


## Places a new thing; returns its ref ({} if refused). `what` is the EnemyDef,
## NpcDef or ZoneDecor.Kind for enemies, people and objects, a name for landmarks,
## a destination zone id for doors; ignored for spawns and graveyards.
## A person already on this map moves here instead (each person stands once).
func add_thing(kind: String, p: Vector2i, what: Variant = null) -> Dictionary:
	if not has_tile(p): # off the map, or a hole in its shape
		return {}
	return _change(func():
		match kind:
			"enemy":
				var s := EnemySpawn.new()
				s.enemy = what
				s.tile = p
				zone.enemy_spawns.append(s)
				return ref(kind, zone.enemy_spawns.size() - 1)
			"npc":
				for i in zone.npcs.size():
					if zone.npcs[i].npc.id == what.id:
						zone.npcs[i].tile = p
						return ref(kind, i)
				var n := NpcSpawn.new()
				n.npc = what
				n.tile = p
				zone.npcs.append(n)
				return ref(kind, zone.npcs.size() - 1)
			"decor":
				var d := ZoneDecor.new()
				d.kind = int(what) as ZoneDecor.Kind
				d.tile = p
				zone.decor.append(d)
				return ref(kind, zone.decor.size() - 1)
			"landmark":
				var l := ZoneLandmark.new()
				l.name = str(what) if what != null else "New place"
				l.tile = p
				zone.landmarks.append(l)
				return ref(kind, zone.landmarks.size() - 1)
			"exit":
				var e := ZoneExit.new()
				e.tile = p
				e.to_zone = StringName(str(what)) if what != null else &""
				e.to_tile = p
				zone.exits.append(e)
				return ref(kind, zone.exits.size() - 1)
			"hero_spawn", "graveyard":
				var list := things(kind)
				if list.has(p):
					return ref(kind, list.find(p))
				list.append(p)
				return ref(kind, list.size() - 1)
		return {})


## Moves a thing to tile `p` (its patrol, if any, moves along with it).
func move_thing(r: Dictionary, p: Vector2i) -> bool:
	if not has_tile(p) or thing(r) == null:
		return false
	return _change(func():
		var t: Variant = thing(r)
		if t is Vector2i:
			var list := things(r.kind)
			if list.has(p):
				return false
			list[r.index] = p
			return true
		var by: Vector2i = p - t.tile
		t.tile = p
		if r.kind == "enemy":
			for i in t.patrol.size():
				t.patrol[i] += by
		if r.kind == "exit" and (t.to_zone == &"" or t.to_zone == zone.id):
			pass # a lift's arrival stays where it was
		return true)


func remove_thing(r: Dictionary) -> bool:
	if thing(r) == null:
		return false
	return _change(func():
		things(r.kind).remove_at(r.index)
		return true)


## Sets properties of a thing (e.g. {"level": 5}, {"label": "Well"}, {"enemy": def}).
func set_thing(r: Dictionary, values: Dictionary) -> void:
	if thing(r) == null or thing(r) is Vector2i:
		return
	_change(func():
		var t: Resource = thing(r)
		for k in values:
			if k in t:
				t.set(k, values[k]))


## Replaces an enemy's patrol route (waypoints, in order; empty: it stands guard).
func set_patrol(r: Dictionary, points: Array) -> void:
	if r.kind != "enemy" or thing(r) == null:
		return
	_change(func():
		var route: Array[Vector2i] = []
		for p in points:
			route.append(p)
		thing(r).patrol = route)


## Where each person is placed in other zones (npc id -> zone id), for the palette and
## so placing someone here can say where they come from.
static func placements(except_zone: StringName = &"") -> Dictionary:
	var out := {}
	for z: ZoneDef in ContentDB.zones.values():
		if z.id == except_zone:
			continue
		for n in z.npcs:
			if n != null and n.npc != null:
				out[n.npc.id] = z.id
	return out


# --- Map size --------------------------------------------------------------------

## What would be cut off by resizing (`grow` per side: rows or columns added, negative
## to remove; keys are the SIDES directions): plain descriptions.
func resize_losses(grow: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = []
	var by := Vector2i(int(grow.get(Vector2i.LEFT, 0)), int(grow.get(Vector2i.UP, 0)))
	var new_size := _grown_size(grow)
	for r in all_things():
		var t := thing_tile(r) + by
		if t.x < 0 or t.y < 0 or t.x >= new_size.x or t.y >= new_size.y:
			out.append("%s at (%d, %d)" % [describe(r), thing_tile(r).x, thing_tile(r).y])
	for s in zone.enemy_spawns:
		for w in s.patrol:
			var t: Vector2i = w + by
			if t.x < 0 or t.y < 0 or t.x >= new_size.x or t.y >= new_size.y:
				out.append("a patrol point of %s at (%d, %d)" % [s.enemy.display_name, w.x, w.y])
	return out


func _grown_size(grow: Dictionary) -> Vector2i:
	return Vector2i(width() + int(grow.get(Vector2i.LEFT, 0)) + int(grow.get(Vector2i.RIGHT, 0)),
			depth() + int(grow.get(Vector2i.UP, 0)) + int(grow.get(Vector2i.DOWN, 0)))


## Adds (or, negative, removes) rows and columns on each side. New tiles get `fill`
## ground at `fill_height`. Everything on the map keeps its place on the ground (its
## coordinates move with it); things cut off are removed. Returns false if the map
## would end up smaller than 4×4.
func resize(grow: Dictionary, fill: String, fill_height: int) -> bool:
	var new_size := _grown_size(grow)
	if new_size.x < 4 or new_size.y < 4 or not tileset.terrains.has(fill):
		return false
	return _change(func():
		var tc := _legend_char(zone.terrain_legend, fill)
		var hc := ZoneDef.HEIGHT_CHARS[clampi(fill_height, 0, MAX_HEIGHT)]
		_resize_rows(grow, {"terrain_rows": tc, "height_rows": hc, "prop_rows": ".", "walk_rows": ".", "sight_rows": "."})
		return true)


## Fills for rows added around the map that hold no tiles (holes).
const HOLE_FILLS := {"terrain_rows": ZoneDef.NO_TILE, "height_rows": ZoneDef.NO_TILE, "prop_rows": ".",
		"walk_rows": "#", "sight_rows": "."}


## Grows the map's rectangle with holes so every tile of `tiles` is inside it, plus
## `margin` more on each side that grows (room to keep painting). One undo step.
## Returns how far the map's coordinates moved (add it to tiles held from before).
func grow_to_include(tiles: Array, margin := 0) -> Vector2i:
	var grow := {}
	for p: Vector2i in tiles:
		if p.x < 0:
			grow[Vector2i.LEFT] = maxi(grow.get(Vector2i.LEFT, 0), -p.x + margin)
		if p.y < 0:
			grow[Vector2i.UP] = maxi(grow.get(Vector2i.UP, 0), -p.y + margin)
		if p.x >= width():
			grow[Vector2i.RIGHT] = maxi(grow.get(Vector2i.RIGHT, 0), p.x - width() + 1 + margin)
		if p.y >= depth():
			grow[Vector2i.DOWN] = maxi(grow.get(Vector2i.DOWN, 0), p.y - depth() + 1 + margin)
	if grow.is_empty():
		return Vector2i.ZERO
	_change(func(): _resize_rows(grow, HOLE_FILLS))
	return Vector2i(grow.get(Vector2i.LEFT, 0), grow.get(Vector2i.UP, 0))


## Rows and columns on each side holding no tile (what `trim` would cut), per SIDES
## direction, as negative grow amounts.
func trimmable() -> Dictionary:
	var lo := Vector2i(width(), depth())
	var hi := Vector2i(-1, -1)
	for y in depth():
		for x in width():
			if has_tile(Vector2i(x, y)):
				lo = lo.min(Vector2i(x, y))
				hi = hi.max(Vector2i(x, y))
	var out := {}
	if hi.x < 0:
		return out # no tile at all: nothing sensible to trim to
	for pair in [[Vector2i.LEFT, lo.x], [Vector2i.UP, lo.y], [Vector2i.RIGHT, width() - 1 - hi.x],
			[Vector2i.DOWN, depth() - 1 - hi.y]]:
		if pair[1] > 0:
			out[pair[0]] = -pair[1]
	return out


## Cuts the empty rows and columns off the map's sides (one undo step; things on
## them are removed). Returns how far the map's coordinates moved.
func trim() -> Vector2i:
	var grow := trimmable()
	if grow.is_empty():
		return Vector2i.ZERO
	_change(func(): _resize_rows(grow, HOLE_FILLS))
	return Vector2i(grow.get(Vector2i.LEFT, 0), grow.get(Vector2i.UP, 0))


## Adds (negative: removes) rows and columns per side, new ones filled per row key
## from `fills`; moves things, patrols, lifts, edge offsets and `shift` with the
## ground. Call inside _change.
func _resize_rows(grow: Dictionary, fills: Dictionary) -> void:
	var new_size := _grown_size(grow)
	var by := Vector2i(int(grow.get(Vector2i.LEFT, 0)), int(grow.get(Vector2i.UP, 0)))
	for key in ROW_KEYS:
		var old: PackedStringArray = zone.get(key)
		var rows: PackedStringArray = []
		for y in new_size.y:
			var row := ""
			for x in new_size.x:
				var o := Vector2i(x, y) - by
				if o.y >= 0 and o.y < old.size() and o.x >= 0 and o.x < old[o.y].length():
					row += old[o.y][o.x]
				else:
					row += fills[key]
			rows.append(row)
		zone.set(key, rows)
	_shift_things(by, new_size)
	for e in zone.edges:
		e.offset -= by.y if e.side.x != 0 else by.x
	shift += by


func _shift_things(by: Vector2i, new_size: Vector2i) -> void:
	var inside := func(t: Vector2i) -> bool:
		return t.x >= 0 and t.y >= 0 and t.x < new_size.x and t.y < new_size.y
	for kind in THING_ARRAYS:
		var list := things(kind)
		for i in range(list.size() - 1, -1, -1):
			var t: Variant = list[i]
			if t is Vector2i:
				if inside.call(t + by):
					list[i] = t + by
				else:
					list.remove_at(i)
				continue
			if not inside.call(t.tile + by):
				list.remove_at(i)
				continue
			t.tile += by
			if kind == "enemy":
				var route: Array[Vector2i] = []
				for w in t.patrol:
					if inside.call(w + by):
						route.append(w + by)
				t.patrol = route
			if kind == "exit" and (t.to_zone == &"" or t.to_zone == zone.id):
				t.to_tile += by


# --- Map edges ------------------------------------------------------------------------

## The edge leading off `side` (a SIDES direction), or null.
func edge_on(side: Vector2i) -> ZoneEdge:
	for e in zone.edges:
		if e.side == side:
			return e
	return null


## Links `side` to `to_zone` (with rows/columns shifted by `offset`); an empty
## `to_zone` removes the link. ZoneSaver writes the matching edge into the other map.
func set_edge(side: Vector2i, to_zone: StringName, offset: int) -> void:
	_change(func():
		for i in range(zone.edges.size() - 1, -1, -1):
			if zone.edges[i].side == side:
				zone.edges.remove_at(i)
		if to_zone != &"":
			var e := ZoneEdge.new()
			e.side = side
			e.to_zone = to_zone
			e.offset = offset
			zone.edges.append(e))


## The tiles along `side` you can walk off from (an edge's gate).
func edge_tiles(side: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var count := width() if side.y != 0 else depth()
	for i in count:
		var p: Vector2i
		match side:
			Vector2i.UP:
				p = Vector2i(i, 0)
			Vector2i.DOWN:
				p = Vector2i(i, depth() - 1)
			Vector2i.LEFT:
				p = Vector2i(0, i)
			_:
				p = Vector2i(width() - 1, i)
		if is_walkable(p):
			out.append(p)
	return out


# --- Names ------------------------------------------------------------------------------

## A short plain name for a thing ("Wolf (Lv 3)", "Hilda", "Well", "Door to Deepcut").
func describe(r: Dictionary) -> String:
	var t: Variant = thing(r)
	match r.kind:
		"enemy":
			var lv: int = t.level if t.level > 0 else t.enemy.level
			return "%s (Lv %d)" % [t.enemy.display_name, lv]
		"npc":
			return t.npc.display_name
		"decor":
			var k := pretty(ZoneDecor.Kind.keys()[t.kind])
			return "%s \"%s\"" % [k, t.label] if t.label != "" else k
		"landmark":
			return "Landmark \"%s\"" % t.name
		"exit":
			return "Lift" if t.to_zone == &"" or t.to_zone == zone.id else "Door to %s" % zone_name(t.to_zone)
		"hero_spawn":
			return "Hero spawn point"
		"graveyard":
			return "Graveyard"
	return r.kind


static func zone_name(id: StringName) -> String:
	var z: ZoneDef = ContentDB.zones.get(id)
	return z.display_name if z != null else String(id)


static func pretty(id: String) -> String:
	return id.replace("_", " ").capitalize()
