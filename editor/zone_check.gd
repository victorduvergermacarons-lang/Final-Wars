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
		if not grid.has_tile(p):
			out.append("The %s at (%d, %d) is where the map has no tile." % [where[p], p.x, p.y])
		elif not grid.is_walkable(p):
			out.append("The %s at (%d, %d) is on a tile you can't stand on." % [where[p], p.x, p.y])
		elif not reach.has(p):
			out.append("The %s at (%d, %d) can't be reached on foot." % [where[p], p.x, p.y])
	for d in z.decor:
		if not grid.has_tile(d.tile):
			out.append("The %s at (%d, %d) is where the map has no tile." % [d.label if d.label != "" else "object", d.tile.x, d.tile.y])
	for e in z.exits:
		if not grid.has_tile(e.tile):
			out.append("The door at (%d, %d) is where the map has no tile." % [e.tile.x, e.tile.y])
		elif not reach.has(e.tile):
			out.append("The exit at (%d, %d) can't be reached on foot." % [e.tile.x, e.tile.y])
	for edge in z.edges:
		var count := 0
		for p in reach:
			if not grid.in_bounds(p + edge.side):
				count += 1
		if count < 2:
			out.append("The way to %s (the map's edge) can't be reached on foot." % edge.to_zone)
	return out


## Doors and map edges that lead nowhere sensible. `zones` maps zone id -> ZoneDef
## for the other maps (ContentDB.zones by default; `z` itself is used for its own id).
static func link_problems(z: ZoneDef, zones: Dictionary = {}) -> PackedStringArray:
	if zones.is_empty():
		zones = ContentDB.zones
	var out: PackedStringArray = []
	var grids := {}
	var grid_of := func(id: StringName) -> GridModel:
		if id == z.id:
			id = &"__self"
		if not grids.has(id):
			var d: ZoneDef = z if id == &"__self" else zones.get(id)
			grids[id] = GridModel.from_zone(d) if d != null else null
		return grids[id]
	for e in z.exits:
		var to: StringName = e.to_zone if e.to_zone != &"" else z.id
		var dest: ZoneDef = z if to == z.id else zones.get(to)
		if dest == null:
			out.append("The door at (%d, %d) leads to a map that doesn't exist (%s)." % [e.tile.x, e.tile.y, to])
			continue
		var g: GridModel = grid_of.call(to)
		if g == null or not g.in_bounds(e.to_tile) or not g.is_walkable(e.to_tile):
			out.append("The door at (%d, %d) leads onto a tile you can't stand on in %s (%d, %d)."
					% [e.tile.x, e.tile.y, dest.display_name, e.to_tile.x, e.to_tile.y])
			continue
		if to != z.id and not _leads_back(dest, z.id):
			out.append("The door at (%d, %d) to %s is one-way: %s has no door or edge back here."
					% [e.tile.x, e.tile.y, dest.display_name, dest.display_name])
	var mine: GridModel = grid_of.call(z.id)
	for edge in z.edges:
		var dest: ZoneDef = zones.get(edge.to_zone)
		if dest == null:
			out.append("An edge leads to a map that doesn't exist (%s)." % edge.to_zone)
			continue
		var g: GridModel = grid_of.call(edge.to_zone)
		var landing := 0
		var gate := 0
		for p in edge_gate(mine, edge.side):
			gate += 1
			var t := edge.arrival(p, Vector2i(g.width, g.depth))
			if g.in_bounds(t) and g.is_walkable(t):
				landing += 1
		if gate == 0:
			out.append("The edge to %s has no open tile to walk off from." % dest.display_name)
		elif landing == 0:
			out.append("The edge to %s lands only on blocked tiles there (check its offset)." % dest.display_name)
	return out


## Walkable tiles along a side of `grid` (the gate you can walk off from).
static func edge_gate(grid: GridModel, side: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var count := grid.width if side.y != 0 else grid.depth
	for i in count:
		var p: Vector2i
		match side:
			Vector2i.UP:
				p = Vector2i(i, 0)
			Vector2i.DOWN:
				p = Vector2i(i, grid.depth - 1)
			Vector2i.LEFT:
				p = Vector2i(0, i)
			_:
				p = Vector2i(grid.width - 1, i)
		if grid.is_walkable(p):
			out.append(p)
	return out


static func _leads_back(dest: ZoneDef, id: StringName) -> bool:
	for e in dest.exits:
		if e.to_zone == id:
			return true
	for e in dest.edges:
		if e.to_zone == id:
			return true
	return false


## People and enemies quests need that this version of `z` would leave on no map
## (compared with the game as loaded, so only new losses count).
static func story_problems(z: ZoneDef) -> PackedStringArray:
	var out: PackedStringArray = []
	var placed_before := {}
	var placed_now := {}
	var enemies_before := {}
	var enemies_now := {}
	for other: ZoneDef in ContentDB.zones.values():
		for n in other.npcs:
			if n != null and n.npc != null:
				placed_before[n.npc.id] = true
				if other.id != z.id:
					placed_now[n.npc.id] = true
		for s in other.enemy_spawns:
			if s != null and s.enemy != null and not other.enemy_pens:
				enemies_before[s.enemy.id] = true
				if other.id != z.id:
					enemies_now[s.enemy.id] = true
	for n in z.npcs:
		placed_now[n.npc.id] = true
	for s in z.enemy_spawns:
		enemies_now[s.enemy.id] = true
	var ids := ContentDB.quests.keys()
	ids.sort()
	for qid in ids:
		var q: QuestDef = ContentDB.quests[qid]
		var people := {q.giver: true, q.turn_in_npc(): true}
		for o in q.objectives:
			if o.npc != &"" and o.kind in [QuestObjective.Kind.TALK, QuestObjective.Kind.DELIVER,
					QuestObjective.Kind.INTERACT, QuestObjective.Kind.ESCORT]:
				people[o.npc] = true
			if o.kind == QuestObjective.Kind.KILL and enemies_before.has(o.enemy) and not enemies_now.has(o.enemy):
				var def: EnemyDef = ContentDB.enemies.get(o.enemy)
				out.append("Quest \"%s\" asks you to defeat %s, and none are left on any map."
						% [q.title, def.display_name if def != null else String(o.enemy)])
		for id in people:
			if id != &"" and placed_before.has(id) and not placed_now.has(id):
				var npc: NpcDef = ContentDB.npcs.get(id)
				out.append("Quest \"%s\" needs %s, who is no longer on any map."
						% [q.title, npc.display_name if npc != null else String(id)])
	return out
