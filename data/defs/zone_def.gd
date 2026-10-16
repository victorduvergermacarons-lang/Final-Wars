class_name ZoneDef
extends Resource
## Authoring data for one zone's grid. Rows are strings so a zone can be edited
## by hand in the inspector or the .tres text.
##
## height_rows: one char per tile, '0'-'9' then 'a'-'z' for heights 10-35.
## walk_rows:   '.' walkable, any other char (e.g. '#') blocked.
## Row 0 is the top (smallest y). Every row must be `width` chars long.
##
## Tiled zones also name a tileset (res://assets/tiles/<id>/) and give a terrain
## layer: terrain_rows, one char per tile, each char mapped to one of the
## tileset's terrain kinds by terrain_legend. For those zones the tileset decides
## walkability: ContentDB rebuilds walk_rows from it at load (bake_walkability).
## prop_rows (optional, '.' = none) put props from the tileset's prop groups on
## tiles, mapped by prop_legend; props and terrain also fill sight_rows ('#'
## blocks line of sight and projectiles).

@export var id: StringName = &""
@export var display_name: String = ""
@export var height_rows: PackedStringArray = []
@export var walk_rows: PackedStringArray = []
## Where released heroes respawn (nearest one wins).
@export var graveyards: Array[Vector2i] = []
@export var hero_spawns: Array[Vector2i] = []
@export var enemy_spawns: Array[EnemySpawn] = []
@export var exits: Array[ZoneExit] = []
## Named places drawn on the map.
@export var landmarks: Array[ZoneLandmark] = []
## Map sides that lead into other zones (walk off the edge).
@export var edges: Array[ZoneEdge] = []
@export var npcs: Array[NpcSpawn] = []
## Tileset id (see TilesetData); empty for placeholder-drawn zones.
@export var tileset: StringName = &""
@export var terrain_rows: PackedStringArray = []
## Terrain char -> terrain kind name in the tileset, e.g. {".": "grass", "~": "water"}.
@export var terrain_legend: Dictionary = {}
## One char per tile, '.' = no prop; others map to prop groups via prop_legend.
@export var prop_rows: PackedStringArray = []
@export var prop_legend: Dictionary = {}
## '#' blocks line of sight; empty = nothing does (only height). Baked for tiled zones.
@export var sight_rows: PackedStringArray = []

const HEIGHT_CHARS := "0123456789abcdefghijklmnopqrstuvwxyz"


func get_width() -> int:
	return height_rows[0].length() if not height_rows.is_empty() else 0


func get_depth() -> int:
	return height_rows.size()


func has_terrain() -> bool:
	return tileset != &"" and not terrain_rows.is_empty()


## The prop group at `p` ("" for none).
func prop_at(p: Vector2i) -> String:
	if p.y < 0 or p.y >= prop_rows.size() or p.x < 0 or p.x >= prop_rows[p.y].length():
		return ""
	return str(prop_legend.get(prop_rows[p.y][p.x], ""))


## The terrain kind at `p` ("" outside the map or without a terrain layer).
func terrain_at(p: Vector2i) -> String:
	if p.y < 0 or p.y >= terrain_rows.size() or p.x < 0 or p.x >= terrain_rows[p.y].length():
		return ""
	return str(terrain_legend.get(terrain_rows[p.y][p.x], ""))


## Rebuilds walk_rows and sight_rows from the tileset: a tile is walkable when
## its terrain is (all variants of a terrain agree; see validate_terrain) and its
## prop, if any, is; it blocks sight when its top block or its prop does.
func bake_walkability(ts: TilesetData) -> void:
	var walk: PackedStringArray = []
	var sight: PackedStringArray = []
	for y in terrain_rows.size():
		var wrow := ""
		var srow := ""
		for x in terrain_rows[y].length():
			var p := Vector2i(x, y)
			var terrain := terrain_at(p)
			var walkable := ts.terrain_walkable(terrain)
			var blocks := ts.blocks_sight(ts.pick(terrain, p))
			var group := prop_at(p)
			if group != "":
				var prop := ts.pick_prop(group, p)
				walkable = walkable and ts.is_walkable(prop)
				blocks = blocks or ts.blocks_sight(prop)
			wrow += "." if walkable else "#"
			srow += "#" if blocks else "."
		walk.append(wrow)
		sight.append(srow)
	walk_rows = walk
	sight_rows = sight


## Problems with the terrain layer against its tileset (empty = fine).
func validate_terrain(ts: TilesetData) -> PackedStringArray:
	var errors: PackedStringArray = []
	if ts == null:
		return PackedStringArray(["%s: unknown tileset %s" % [id, tileset]])
	if terrain_rows.size() != height_rows.size():
		errors.append("%s: terrain_rows has %d rows, height_rows has %d" % [id, terrain_rows.size(), height_rows.size()])
	for y in terrain_rows.size():
		if terrain_rows[y].length() != get_width():
			errors.append("%s: terrain row %d has length %d, expected %d" % [id, y, terrain_rows[y].length(), get_width()])
		for x in terrain_rows[y].length():
			var c := terrain_rows[y][x]
			if not terrain_legend.has(c):
				errors.append("%s: terrain char '%s' at (%d,%d) is not in the legend" % [id, c, x, y])
	for c in terrain_legend:
		var name := str(terrain_legend[c])
		if not ts.terrains.has(name):
			errors.append("%s: legend '%s' names unknown terrain %s" % [id, c, name])
		elif not ts.terrain_walkability_consistent(name):
			errors.append("%s: terrain %s mixes walkable and unwalkable tiles" % [id, name])
	if not prop_rows.is_empty() and prop_rows.size() != terrain_rows.size():
		errors.append("%s: prop_rows has %d rows, terrain_rows has %d" % [id, prop_rows.size(), terrain_rows.size()])
	for y in prop_rows.size():
		if prop_rows[y].length() != get_width():
			errors.append("%s: prop row %d has length %d, expected %d" % [id, y, prop_rows[y].length(), get_width()])
		for x in prop_rows[y].length():
			var c := prop_rows[y][x]
			if c != "." and not prop_legend.has(c):
				errors.append("%s: prop char '%s' at (%d,%d) is not in the legend" % [id, c, x, y])
	for c in prop_legend:
		if not ts.props.has(str(prop_legend[c])):
			errors.append("%s: prop legend '%s' names unknown prop group %s" % [id, c, prop_legend[c]])
	return errors


static func parse_height(c: String) -> int:
	return HEIGHT_CHARS.find(c.to_lower())


func validate() -> PackedStringArray:
	var errors: PackedStringArray = []
	var w := get_width()
	if w == 0:
		errors.append("%s: empty height_rows" % id)
		return errors
	if walk_rows.size() != height_rows.size():
		errors.append("%s: walk_rows has %d rows, height_rows has %d" % [id, walk_rows.size(), height_rows.size()])
	for y in height_rows.size():
		var row := height_rows[y]
		if row.length() != w:
			errors.append("%s: height row %d has length %d, expected %d" % [id, y, row.length(), w])
		for x in row.length():
			if parse_height(row[x]) < 0:
				errors.append("%s: bad height char '%s' at (%d,%d)" % [id, row[x], x, y])
	if not sight_rows.is_empty() and sight_rows.size() != height_rows.size():
		errors.append("%s: sight_rows has %d rows, height_rows has %d" % [id, sight_rows.size(), height_rows.size()])
	for y in sight_rows.size():
		if sight_rows[y].length() != w:
			errors.append("%s: sight row %d has length %d, expected %d" % [id, y, sight_rows[y].length(), w])
	for y in walk_rows.size():
		if walk_rows[y].length() != w:
			errors.append("%s: walk row %d has length %d, expected %d" % [id, y, walk_rows[y].length(), w])
	for p in graveyards + hero_spawns:
		if p.x < 0 or p.y < 0 or p.x >= w or p.y >= height_rows.size():
			errors.append("%s: point %s out of bounds" % [id, p])
	for n in npcs:
		if n == null or n.npc == null:
			errors.append("%s: NPC spawn without an NPC" % id)
	for e in exits:
		if e == null or e.to_zone == &"":
			errors.append("%s: exit without a destination" % id)
		elif e.tile.x < 0 or e.tile.y < 0 or e.tile.x >= w or e.tile.y >= height_rows.size():
			errors.append("%s: exit %s out of bounds" % [id, e.tile])
	for edge in edges:
		if edge == null or edge.to_zone == &"":
			errors.append("%s: edge without a destination" % id)
		elif not GridModel.DIRECTIONS.has(edge.side):
			errors.append("%s: edge side %s is not a direction" % [id, edge.side])
	for spawn in enemy_spawns:
		if spawn == null or spawn.enemy == null:
			errors.append("%s: enemy spawn without an enemy" % id)
		elif spawn.tile.x < 0 or spawn.tile.y < 0 or spawn.tile.x >= w or spawn.tile.y >= height_rows.size():
			errors.append("%s: enemy spawn %s out of bounds" % [id, spawn.tile])
	return errors
