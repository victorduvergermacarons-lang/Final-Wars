extends GutTest
## Where the water sound near the local hero comes from (WaterSound, plain
## functions): which tiles are water, the look around the hero, clusters, the
## nearest tile of each, the cap, and the level by distance.


func _zone(rows: Array) -> ZoneDef:
	var z := ZoneDef.new()
	z.id = &"pond_test"
	z.tileset = &"iso_basic"
	z.terrain_legend = {"g": "grass", "w": "water", "l": "light_water", "r": "grey_water", "f": "ford"}
	var heights: PackedStringArray = []
	var walk: PackedStringArray = []
	var terrain: PackedStringArray = []
	for r in rows:
		terrain.append(r)
		heights.append("0".repeat(r.length()))
		walk.append(".".repeat(r.length()))
	z.terrain_rows = terrain
	z.height_rows = heights
	z.walk_rows = walk
	return z


func _ts() -> TilesetData:
	return ContentDB.tilesets[&"iso_basic"]


func _all(index: Dictionary) -> Array:
	var out := []
	for b in index:
		out.append_array(index[b])
	return out


func test_water_terrains_come_from_the_catalog() -> void:
	var ts := _ts()
	for t in ["water", "deep_water", "light_water", "grey_water"]:
		assert_true(ts.is_water_terrain(t), "%s is water" % t)
	for t in ["grass", "ford", "water_rocks", "cobble"]:
		assert_false(ts.is_water_terrain(t), "%s isn't" % t)


func test_the_index_holds_only_water_tiles() -> void:
	var z := _zone(["gggwg", "glggr", "gffgg"])
	var tiles := _all(WaterSound.index(z, _ts()))
	tiles.sort()
	assert_eq(tiles, [Vector2i(1, 1), Vector2i(3, 0), Vector2i(4, 1)], "water, light water and grey water; not the ford")
	assert_true(WaterSound.index(_zone(["ggg"]), _ts()).is_empty(), "no water: nothing")


func test_near_keeps_the_radius_and_spans_buckets() -> void:
	var row := "g".repeat(40)
	var rows := []
	for y in 20:
		rows.append(row)
	rows[5] = "w".repeat(40) # a river along row 5, across five buckets
	var index := WaterSound.index(_zone(rows), _ts())
	var got := WaterSound.near(index, Vector2(20, 5), 3.0)
	assert_eq(got.size(), 7, "x 17 to 23")
	for t in got:
		assert_lte(Vector2(t).distance_to(Vector2(20, 5)), 3.0)
	assert_true(WaterSound.near(index, Vector2(20, 15), 3.0).is_empty(), "10 rows away: none")


func test_one_cluster_gives_one_spot_at_its_nearest_tile() -> void:
	var tiles: Array[Vector2i] = []
	for x in range(0, 10):
		tiles.append(Vector2i(x, 0)) # one river, 10 tiles long
	assert_eq(WaterSound.spots(tiles, Vector2(6.2, 4), 3), [Vector2i(6, 0)] as Array[Vector2i])


func test_diagonal_neighbours_are_one_cluster() -> void:
	var tiles: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 1), Vector2i(2, 2)]
	assert_eq(WaterSound.spots(tiles, Vector2(5, 5), 3).size(), 1)


func test_separate_clusters_nearest_first_and_capped() -> void:
	var tiles: Array[Vector2i] = []
	# Four ponds, 2 x 2 each, at different distances from (0, 0).
	for corner in [Vector2i(9, 0), Vector2i(3, 0), Vector2i(0, 6), Vector2i(-8, -8)]:
		for d in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
			tiles.append(corner + d)
	var got := WaterSound.spots(tiles, Vector2(0, 0), 3)
	assert_eq(got, [Vector2i(3, 0), Vector2i(0, 6), Vector2i(9, 0)] as Array[Vector2i],
			"each pond's nearest tile, the three nearest ponds, nearest first")
	assert_eq(WaterSound.spots(tiles, Vector2(0, 0), 1), [Vector2i(3, 0)] as Array[Vector2i])
	assert_true(WaterSound.spots([] as Array[Vector2i], Vector2.ZERO, 3).is_empty())


func test_gain_by_distance() -> void:
	assert_almost_eq(WaterSound.gain(0.0, 10.0, 1.5), 1.0, 0.001, "loudest at the water")
	assert_almost_eq(WaterSound.gain(10.0, 10.0, 1.5), 0.0, 0.001, "gone at the radius")
	assert_almost_eq(WaterSound.gain(12.0, 10.0, 1.5), 0.0, 0.001)
	assert_almost_eq(WaterSound.gain(5.0, 10.0, 1.0), 0.5, 0.001, "falloff 1 is a straight line")
	assert_lt(WaterSound.gain(5.0, 10.0, 1.5), 0.5, "a steeper falloff is quieter halfway")


func test_the_shipped_maps_with_water_have_water() -> void:
	for id in [&"town", &"greenfields", &"crossing", &"deepcut", &"deepcut_road", &"wilds", &"tidereach_shore"]:
		var z: ZoneDef = ContentDB.zones[id]
		assert_false(WaterSound.index(z, ContentDB.tilesets.get(z.tileset)).is_empty(), "%s has water" % id)
