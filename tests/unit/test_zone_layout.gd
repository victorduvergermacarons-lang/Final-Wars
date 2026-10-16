extends GutTest
## Every zone stays playable whatever its tiles look like: the places gameplay
## needs (spawns, NPCs, graveyards, patrol routes, landmarks, map edges) are
## walkable and reachable on foot (Jump 2) from where heroes start.

const JUMP := 2


func _reachable(grid: GridModel, start: Vector2i) -> Dictionary:
	var seen := {start: true}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var p: Vector2i = queue.pop_front()
		for d in GridModel.DIRECTIONS:
			var n: Vector2i = p + d
			if not seen.has(n) and grid.can_step(p, n, JUMP):
				seen[n] = true
				queue.append(n)
	return seen


func _places(z: ZoneDef) -> Dictionary:
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


func test_every_place_is_walkable_and_reachable() -> void:
	for z: ZoneDef in ContentDB.zones.values():
		var grid := GridModel.from_zone(z)
		var reach := _reachable(grid, z.hero_spawns[0])
		var places := _places(z)
		for p in places:
			assert_true(grid.is_walkable(p), "%s: %s at %s is walkable" % [z.id, places[p], p])
			assert_true(reach.has(p), "%s: %s at %s can be reached" % [z.id, places[p], p])


func test_linked_edges_can_be_reached() -> void:
	for z: ZoneDef in ContentDB.zones.values():
		var grid := GridModel.from_zone(z)
		var reach := _reachable(grid, z.hero_spawns[0])
		for edge in z.edges:
			var count := 0
			for p in reach:
				var beyond: Vector2i = p + edge.side
				if not grid.in_bounds(beyond):
					count += 1
			assert_gt(count, 3, "%s: the edge to %s can be walked off from several tiles" % [z.id, edge.to_zone])


func test_written_walk_and_sight_rows_match_the_tileset() -> void:
	# Tiled zones keep walk_rows/sight_rows in the file for reading; ContentDB
	# rebuilds them from the tileset at load. They must agree.
	for z: ZoneDef in ContentDB.zones.values():
		if not z.has_terrain():
			continue
		var on_disk: ZoneDef = ResourceLoader.load(z.resource_path, "", ResourceLoader.CACHE_MODE_IGNORE)
		assert_eq(Array(on_disk.walk_rows), Array(z.walk_rows), "%s walk_rows" % z.id)
		assert_eq(Array(on_disk.sight_rows), Array(z.sight_rows), "%s sight_rows" % z.id)


func test_greenfields_has_the_promised_features() -> void:
	var z: ZoneDef = ContentDB.zones[&"greenfields"]
	var count := {}
	var max_rocky := 0
	var grid := GridModel.from_zone(z)
	for y in grid.depth:
		for x in grid.width:
			var t := z.terrain_at(Vector2i(x, y))
			count[t] = count.get(t, 0) + 1
			if t == "rocky_ground":
				max_rocky = maxi(max_rocky, grid.height_at(Vector2i(x, y)))
	assert_gt(count.get("grass", 0), 200, "grass fields")
	assert_gt(count.get("path", 0), 40, "a dirt path")
	assert_gte(max_rocky, 3, "a raised rocky area at least 3 levels high")
	assert_gt(count.get("light_water", 0), 8, "a pond")
	assert_gt(count.get("water_rocks", 0) + count.get("water_tall_rocks", 0), 3, "rocks in the water")
