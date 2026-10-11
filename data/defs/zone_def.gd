class_name ZoneDef
extends Resource
## Authoring data for one zone's grid. Rows are strings so a zone can be edited
## by hand in the inspector or the .tres text.
##
## height_rows: one char per tile, '0'-'9' then 'a'-'z' for heights 10-35.
## walk_rows:   '.' walkable, any other char (e.g. '#') blocked.
## Row 0 is the top (smallest y). Every row must be `width` chars long.

@export var id: StringName = &""
@export var display_name: String = ""
@export var height_rows: PackedStringArray = []
@export var walk_rows: PackedStringArray = []
## Where released heroes respawn (nearest one wins).
@export var graveyards: Array[Vector2i] = []
@export var hero_spawns: Array[Vector2i] = []
@export var enemy_spawns: Array[EnemySpawn] = []
@export var exits: Array[ZoneExit] = []
@export var npcs: Array[NpcSpawn] = []

const HEIGHT_CHARS := "0123456789abcdefghijklmnopqrstuvwxyz"


func get_width() -> int:
	return height_rows[0].length() if not height_rows.is_empty() else 0


func get_depth() -> int:
	return height_rows.size()


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
	for spawn in enemy_spawns:
		if spawn == null or spawn.enemy == null:
			errors.append("%s: enemy spawn without an enemy" % id)
		elif spawn.tile.x < 0 or spawn.tile.y < 0 or spawn.tile.x >= w or spawn.tile.y >= height_rows.size():
			errors.append("%s: enemy spawn %s out of bounds" % [id, spawn.tile])
	return errors
