extends GutTest
## The Wilds (2026-11-19): a 64 x 64 map of streams, puddles and dense vegetation in
## place of the Enemy Testing Grounds, which nothing loads any more.


func _z() -> ZoneDef:
	return ContentDB.zones[&"wilds"]


func test_the_testing_grounds_are_gone_from_the_game() -> void:
	assert_false(ContentDB.zones.has(&"enemy_testing"), "not loaded")
	for z: ZoneDef in ContentDB.zones.values():
		assert_false(z.enemy_pens, "%s: no generated pens" % z.id)
		for e in z.edges:
			assert_ne(e.to_zone, &"enemy_testing", "%s: no edge leads there" % z.id)
		for x in z.exits:
			assert_ne(x.to_zone, &"enemy_testing", "%s: no door leads there" % z.id)
	assert_true(FileAccess.file_exists("res://content/retired/enemy_testing.tres"), "the file stays in the repo")


func test_millbrook_and_tidereach_lead_to_it() -> void:
	var town: ZoneDef = ContentDB.zones[&"town"]
	assert_true(town.edges.any(func(e): return e.to_zone == &"wilds" and e.side == Vector2i(0, -1)))
	assert_true(ContentDB.zones[&"tidereach_shore"].edges.any(func(e): return e.to_zone == &"wilds"))


func test_size_tileset_and_nothing_on_it() -> void:
	var z := _z()
	assert_eq(z.get_width(), 64)
	assert_eq(z.get_depth(), 64)
	assert_eq(z.tileset, &"iso_basic")
	assert_true(z.enemy_spawns.is_empty(), "no enemies")
	assert_true(z.npcs.is_empty(), "no people")
	for q: QuestDef in ContentDB.quests.values():
		assert_ne(q.area, "The Wilds")


func test_streams_puddles_and_dense_vegetation() -> void:
	var z := _z()
	var grid := GridModel.from_zone(z)
	var count := {}
	for y in grid.depth:
		for x in grid.width:
			var t := z.terrain_at(Vector2i(x, y))
			count[t] = count.get(t, 0) + 1
			if t in ["water", "light_water"]:
				assert_false(grid.is_walkable(Vector2i(x, y)), "water isn't walkable at %s" % Vector2i(x, y))
			if t == "ford":
				assert_true(grid.is_walkable(Vector2i(x, y)), "fords are")
	assert_gt(count.get("water", 0), 250, "winding streams")
	assert_gt(count.get("light_water", 0), 60, "puddles")
	var land: int = 64 * 64 - count.get("water", 0) - count.get("light_water", 0) - count.get("ford", 0) - count.get("path", 0)
	var green: int = count.get("tall_grass", 0) + count.get("dense_grass", 0) + count.get("bush", 0)
	assert_gt(float(green) / land, 0.6, "vegetation covers most of the land")


func test_everything_walkable_is_reachable_from_the_gate() -> void:
	var z := _z()
	var grid := GridModel.from_zone(z)
	var start: Vector2i = z.hero_spawns[0]
	var seen := {start: true}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var p: Vector2i = queue.pop_front()
		for d in GridModel.DIRECTIONS:
			var n: Vector2i = p + d
			if grid.in_bounds(n) and not seen.has(n) and grid.can_step(p, n, 2):
				seen[n] = true
				queue.append(n)
	for y in grid.depth:
		for x in grid.width:
			if grid.is_walkable(Vector2i(x, y)):
				assert_true(seen.has(Vector2i(x, y)), "cut off: %s" % Vector2i(x, y))
	assert_true(seen.has(Vector2i(3, 63)), "the south gate (from Millbrook)")
	assert_true(seen.has(Vector2i(0, 4)), "the west gate (from Tidereach)")
