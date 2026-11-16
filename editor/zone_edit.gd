class_name ZoneEdit
extends RefCounted
## The map editor's model: paints a tiled zone's ground, heights and props, keeps
## its walk and sight rows (and a live GridModel, if given) in step, and undoes.
## Works on its own copy of the zone; nothing here draws or saves.

enum Layer { TERRAIN, HEIGHT, PROP }

## Heights the editor paints: the digits of ZoneDef.HEIGHT_CHARS.
const MAX_HEIGHT := 9
## Characters a new legend entry may take, in order (props never use ".").
const LEGEND_CHARS := "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"

var zone: ZoneDef
var tileset: TilesetData
## The live grid to keep in step (the editor's world view reads it); may be null.
var grid: GridModel
## Changed since the last save.
var dirty := false

var _undo: Array = [] # strokes: Array of [layer, tile, old, new]
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


## A working copy of `source` the editor can change freely.
static func copy_of(source: ZoneDef) -> ZoneDef:
	var z: ZoneDef = source.duplicate() # rows are copied; spawns, NPCs and decor shared (read only)
	# Packed arrays are shared between a resource and its shallow duplicate.
	for key in ["height_rows", "walk_rows", "terrain_rows", "prop_rows", "sight_rows"]:
		z.set(key, PackedStringArray(Array(source.get(key))))
	z.terrain_legend = source.terrain_legend.duplicate()
	z.prop_legend = source.prop_legend.duplicate()
	z.friction_tiles = source.friction_tiles.duplicate()
	return z


func width() -> int:
	return zone.get_width()


func depth() -> int:
	return zone.get_depth()


func in_bounds(p: Vector2i) -> bool:
	return p.x >= 0 and p.y >= 0 and p.x < width() and p.y < depth()


## The tiles a square brush of `size` (1, 3, 5…) covers around `center`.
func brush(center: Vector2i, size: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var r := maxi(size, 1) / 2
	for y in range(center.y - r, center.y + r + 1):
		for x in range(center.x - r, center.x + r + 1):
			var p := Vector2i(x, y)
			if in_bounds(p):
				out.append(p)
	return out


# --- Reading ------------------------------------------------------------------

func terrain_at(p: Vector2i) -> String:
	return zone.terrain_at(p)


func height_at(p: Vector2i) -> int:
	return ZoneDef.parse_height(zone.height_rows[p.y][p.x])


func prop_at(p: Vector2i) -> String:
	return zone.prop_at(p)


## What the eyedropper copies: {"terrain", "height", "prop"}.
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


func _paint(layer: Layer, tiles: Array, value_of: Callable) -> Array[Vector2i]:
	var changed: Array[Vector2i] = []
	for p: Vector2i in tiles:
		if not in_bounds(p):
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


func _push(stroke: Array) -> void:
	if stroke.is_empty():
		return
	_undo.append(stroke)
	if _undo.size() > UNDO_LIMIT:
		_undo.pop_front()
	_redo.clear()
	dirty = true


func can_undo() -> bool:
	return not _undo.is_empty()


func can_redo() -> bool:
	return not _redo.is_empty()


## Takes back the last stroke; returns the tiles that changed.
func undo() -> Array[Vector2i]:
	if _undo.is_empty():
		return []
	var stroke: Array = _undo.pop_back()
	_redo.append(stroke)
	var tiles: Array[Vector2i] = []
	for i in range(stroke.size() - 1, -1, -1):
		var c: Array = stroke[i]
		_write(c[0], c[1], c[2])
		tiles.append(c[1])
	dirty = true
	return _rebake(tiles)


func redo() -> Array[Vector2i]:
	if _redo.is_empty():
		return []
	var stroke: Array = _redo.pop_back()
	_undo.append(stroke)
	var tiles: Array[Vector2i] = []
	for c: Array in stroke:
		_write(c[0], c[1], c[3])
		tiles.append(c[1])
	dirty = true
	return _rebake(tiles)


func _read(layer: Layer, p: Vector2i) -> Variant:
	match layer:
		Layer.TERRAIN:
			return terrain_at(p)
		Layer.HEIGHT:
			return height_at(p)
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
		if grid != null:
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
