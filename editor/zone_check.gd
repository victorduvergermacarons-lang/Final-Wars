class_name ZoneCheck
extends RefCounted
## Is a zone still playable? The places gameplay needs (spawns, NPCs, graveyards,
## patrol routes, landmarks, exits, linked map edges) must be walkable and
## reachable on foot (Jump 2) from where heroes start, riding the map's lifts.
## Used by the map editor before saving and by tests/unit/test_zone_layout.gd.

const JUMP := 2


## Every tile reachable on foot from `start` (tile -> true).
static func reachable(grid: GridModel, start: Vector2i, z: ZoneDef = null) -> Dictionary:
	var lifts := {}
	if z != null:
		for e in z.exits:
			if e.to_zone == &"" or e.to_zone == z.id:
				lifts[e.tile] = e.to_tile
	var seen := {start: true}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var p: Vector2i = queue.pop_front()
		if lifts.has(p) and not seen.has(lifts[p]):
			seen[lifts[p]] = true
			queue.append(lifts[p])
		for d in GridModel.DIRECTIONS:
			var n: Vector2i = p + d
			if not seen.has(n) and grid.can_step(p, n, JUMP):
				seen[n] = true
				queue.append(n)
	return seen


## The places that must stay reachable: tile -> what it is.
static func places(z: ZoneDef) -> Dictionary:
	var out := {}
	for p in z.hero_spawns:
		out[p] = "hero spawn"
	for p in z.graveyards:
		out[p] = "graveyard"
	for n in z.npcs:
		out[n.tile] = "NPC %s" % n.npc.id
	for lm in z.landmarks:
		out[lm.tile] = "landmark %s" % lm.name
	for s in z.enemy_spawns:
		out[s.tile] = "%s spawn" % s.enemy.id
		for w in s.patrol:
			out[w] = "%s patrol point" % s.enemy.id
	return out


## Plain-language problems with `z` on `grid` (empty: playable).
static func problems(z: ZoneDef, grid: GridModel) -> PackedStringArray:
	var out: PackedStringArray = []
	if z.hero_spawns.is_empty():
		return PackedStringArray(["The map has no hero spawn point."])
	var reach := reachable(grid, z.hero_spawns[0], z)
	var where := places(z)
	for p in where:
		if not grid.in_bounds(p):
			continue
		if not grid.is_walkable(p):
			out.append("The %s at (%d, %d) is on a tile you can't stand on." % [where[p], p.x, p.y])
		elif not reach.has(p):
			out.append("The %s at (%d, %d) can't be reached on foot." % [where[p], p.x, p.y])
	for e in z.exits:
		if not reach.has(e.tile):
			out.append("The exit at (%d, %d) can't be reached on foot." % [e.tile.x, e.tile.y])
	for edge in z.edges:
		var count := 0
		for p in reach:
			if not grid.in_bounds(p + edge.side):
				count += 1
		if count < 2:
			out.append("The way to %s (the map's edge) can't be reached on foot." % edge.to_zone)
	return out
