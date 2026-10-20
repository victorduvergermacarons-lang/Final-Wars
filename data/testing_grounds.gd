class_name TestingGrounds
extends RefCounted
## Builds the enemy testing map (a ZoneDef with `enemy_pens` set) from the enemy
## data at load: one pen per enemy type, in a row along a road, so any enemy added
## later gets a pen without editing the map.
##
## Layout (x runs east along the road; row 0 is the map's north-east edge):
##   row 0                      hedge
##   rows 1 .. road-2           pens (low stone walls between them), the enemy
##                              stands at SPAWN_ROW; the pen's front row is open
##   rows road, road+1          the road (heroes walk it without aggroing anyone)
##   row road+2                 grass verge
##   last row                   hedge, with the gate back to Millbrook at the west end
## The entrance (spawn point, graveyard, Reset Shrine) is at the west end; elites
## (bosses) get their own arena behind a hedge at the far east end.
##
## Spacing comes from the data, so fighting one enemy can never pull in another:
## an enemy can be dragged up to its leash radius from its spawn, and the hero
## fighting it stands within its longest attack range of it; another enemy
## notices heroes within its aggro radius, and a pack call reaches its own radius.
## Neighbours are placed so those zones never meet, plus MARGIN tiles.

const MARGIN := 3
## Extra tiles between the last pen and the boss arena, and between bosses.
const BOSS_MARGIN := 4
const SPAWN_ROW := 3
## Tiles west of the first pen's reach kept for the entrance.
const ENTRANCE_WIDTH := 8
## The gate back to Millbrook: these columns of the last row.
const GATE := [3, 4]
const SHRINE := Vector2i(6, -1) # y: relative to the road (the row above it)

const LEGEND := {
	".": "grass", "p": "path", "#": "stone_wall", "b": "bush", "c": "cobble", "x": "cracked",
}


## Fills `zone` (keeps its id, name, tileset and edges) with pens for `enemies`
## (EnemyDefs). `shrine`: the NpcDef of the Reset Shrine (or null).
static func build(zone: ZoneDef, enemies: Array, shrine: NpcDef = null) -> void:
	var normal: Array = enemies.filter(func(e): return not e.elite)
	var bosses: Array = enemies.filter(func(e): return e.elite)
	var order := func(a, b): return [a.level, String(a.id)] < [b.level, String(b.id)]
	normal.sort_custom(order)
	bosses.sort_custom(order)
	var max_aggro := 1
	for e in enemies:
		max_aggro = maxi(max_aggro, e.aggro_radius)
	# The road is out of every enemy's aggro radius: walking it pulls nobody.
	var road := SPAWN_ROW + max_aggro + 2
	var depth := road + 4

	# Spawn columns, west to east; bosses keep BOSS_MARGIN more tiles.
	var all: Array = normal + bosses
	var xs: Array[int] = []
	var x := ENTRANCE_WIDTH
	for i in all.size():
		if i == 0:
			x += reach(all[i]) + 1
		else:
			x += spacing(all[i - 1], all[i]) + (BOSS_MARGIN if all[i].elite else 0)
		xs.append(x)
	var width := x + (reach(all.back()) + 2 if not all.is_empty() else 4)
	# The arena hedge: halfway between the last pen and the first boss.
	var arena_x := -1
	if not bosses.is_empty():
		var first := normal.size()
		arena_x = (xs[first - 1] + xs[first]) / 2 if first > 0 else ENTRANCE_WIDTH

	# Terrain, heights.
	var terrain: Array = []
	var heights: Array = []
	for y in depth:
		var trow := ""
		var hrow := ""
		for cx in width:
			var t := "."
			var h := "0"
			if y == 0 or y == depth - 1 or cx == 0 or cx == width - 1:
				t = "b"
				h = "1"
			elif y == road or y == road + 1:
				t = "p"
			elif cx < ENTRANCE_WIDTH and y >= road - 2:
				t = "c"
			elif arena_x >= 0 and cx > arena_x:
				t = "x"
			trow += t
			hrow += h
		terrain.append(trow)
		heights.append(hrow)
	for gx in GATE:
		_put(terrain, Vector2i(gx, depth - 1), "p")
		_put(heights, Vector2i(gx, depth - 1), "0")
	# Low stone walls between pens, from the back hedge to the row before the open front.
	for i in range(1, all.size()):
		var wall_x: int = (xs[i - 1] + xs[i]) / 2
		if arena_x >= 0 and all[i].elite and not all[i - 1].elite:
			continue # the arena hedge goes here instead
		for y in range(1, road - 1):
			_put(terrain, Vector2i(wall_x, y), "#")
			_put(heights, Vector2i(wall_x, y), "1")
	# West wall of the first pen, so the entrance plaza is its own space.
	if not all.is_empty():
		for y in range(1, road - 2):
			_put(terrain, Vector2i(ENTRANCE_WIDTH - 1, y), "#")
			_put(heights, Vector2i(ENTRANCE_WIDTH - 1, y), "1")
	# The boss arena: a hedge across the map with a gate on the road.
	if arena_x >= 0:
		for y in range(1, depth - 1):
			if y == road or y == road + 1:
				continue
			_put(terrain, Vector2i(arena_x, y), "b")
			_put(heights, Vector2i(arena_x, y), "1")

	zone.height_rows = PackedStringArray(heights)
	zone.terrain_rows = PackedStringArray(terrain)
	zone.terrain_legend = LEGEND.duplicate()
	var props: PackedStringArray = []
	for y in depth:
		props.append(".".repeat(width))
	zone.prop_rows = props
	zone.prop_legend = {}
	zone.walk_rows = PackedStringArray() # baked from the tileset by ContentDB
	zone.sight_rows = PackedStringArray()

	# Spawns, signs, entrance.
	var spawns: Array[EnemySpawn] = []
	var landmarks: Array[ZoneLandmark] = []
	for i in all.size():
		var s := EnemySpawn.new()
		s.enemy = all[i]
		s.tile = Vector2i(xs[i], SPAWN_ROW)
		s.respawn_seconds = zone.enemy_respawn_seconds
		spawns.append(s)
		landmarks.append(_landmark("%s (Lv %d)" % [all[i].display_name, all[i].level], Vector2i(xs[i], road - 1)))
	zone.enemy_spawns = spawns
	landmarks.append(_landmark("Enemy Testing Grounds", Vector2i(2, road - 1)))
	if arena_x >= 0:
		landmarks.append(_landmark("Boss Arena", Vector2i(arena_x, road)))
	zone.landmarks = landmarks
	zone.hero_spawns = [Vector2i(GATE[0], road + 1), Vector2i(GATE[1], road + 1),
			Vector2i(GATE[0], road), Vector2i(GATE[1], road)] as Array[Vector2i]
	zone.graveyards = [Vector2i(1, road + 1)] as Array[Vector2i]
	var npcs: Array[NpcSpawn] = []
	if shrine != null:
		var n := NpcSpawn.new()
		n.npc = shrine
		n.tile = Vector2i(SHRINE.x, road + SHRINE.y)
		n.facing = Vector2i(0, 1)
		npcs.append(n)
	zone.npcs = npcs


## How far from its spawn a fight with `e` can reach: its leash, plus its longest
## self-move (a dive or leap can carry it past the leash before it turns back),
## plus where the hero fighting it stands (its longest attack range, at least adjacent).
static func reach(e: EnemyDef) -> int:
	var r := 1
	var moves := 0
	for a in e.abilities:
		r = maxi(r, a.max_range)
		moves = maxi(moves, a.moves_caster_tiles())
	var body := 0
	for o in e.footprint:
		body = maxi(body, absi(o.x) + absi(o.y))
	return e.leash_radius + moves + r + body


## Tiles between the spawns of neighbours `a` (west) and `b` (east): neither
## fight's reach meets the other's aggro radius, nor its pack call.
static func spacing(a: EnemyDef, b: EnemyDef) -> int:
	var need := maxi(reach(a) + b.aggro_radius, reach(b) + a.aggro_radius)
	need = maxi(need, maxi(a.leash_radius + a.pack_call_radius, b.leash_radius + b.pack_call_radius))
	return need + MARGIN + 1


static func _landmark(text: String, tile: Vector2i) -> ZoneLandmark:
	var lm := ZoneLandmark.new()
	lm.name = text
	lm.tile = tile
	return lm


static func _put(rows: Array, p: Vector2i, c: String) -> void:
	var row: String = rows[p.y]
	rows[p.y] = row.substr(0, p.x) + c + row.substr(p.x + 1)
