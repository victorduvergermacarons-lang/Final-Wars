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

const HEIGHT_CHARS := "0123456789abcdefghijklmnopqrstuvwxyz"


func get_width() -> int:
	return height_rows[0].length() if not height_rows.is_empty() else 0


func get_depth() -> int:
	return height_rows.size()


func has_terrain() -> bool:
	return tileset != &"" and not terrain_rows.is_empty()


## The terrain kind at `p` ("" outside the map or without a terrain layer).
func terrain_at(p: Vector2i) -> String:
	if p.y < 0 or p.y >= terrain_rows.size() or p.x < 0 or p.x >= terrain_rows[p.y].length():
		return ""
	return str(terrain_legend.get(terrain_rows[p.y][p.x], ""))


## Rebuilds walk_rows from the tileset: a tile is walkable when its terrain's
## tiles are (all variants of a terrain share walkability; see validate_terrain).
func bake_walkability(ts: TilesetData) -> void:
	var rows: PackedStringArray = []
	for y in terrain_rows.size():
		var row := ""
		for x in terrain_rows[y].length():
			row += "." if ts.terrain_walkable(terrain_at(Vector2i(x, y))) else "#"
		rows.append(row)
	walk_rows = rows


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
