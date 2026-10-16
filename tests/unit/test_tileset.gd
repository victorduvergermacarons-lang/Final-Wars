extends GutTest
## The tileset catalog (assets/tiles/<id>/tileset.json) and its loader.

var basic: TilesetData


func before_all() -> void:
	basic = ContentDB.tilesets.get(&"iso_basic")


func test_basic_tileset_loads_and_validates() -> void:
	assert_not_null(basic, "found by scanning assets/tiles")
	assert_eq(basic.tiles.size(), 115)
	assert_eq(Array(basic.validate()), [])
	assert_eq(basic.cell_size, Vector2i(32, 32))
	assert_eq(basic.level_height, 8, "a block's side is 8 art px")


func test_every_tile_has_its_image() -> void:
	for tid in basic.tiles:
		assert_true(ResourceLoader.exists(basic.tile_path(tid)), basic.tile_path(tid))


func test_walkability_and_sight() -> void:
	assert_true(basic.is_walkable(22), "grass")
	assert_true(basic.is_walkable(14), "dirt path")
	assert_false(basic.is_walkable(86), "water")
	assert_false(basic.is_walkable(104), "light water is water too")
	assert_true(basic.is_walkable(69), "stone slab in water: a ford")
	assert_false(basic.is_walkable(48), "a log blocks the way")
	assert_false(basic.blocks_sight(48), "but you can see over it")
	assert_true(basic.blocks_sight(64), "a tall boulder hides what's behind it")


func test_terrains_and_animations() -> void:
	assert_eq(basic.terrains.grass.fill, "dirt", "grass sits on dirt")
	assert_true(basic.terrains.has("ford"))
	assert_eq(basic.animations.sparkle.frames, [82, 83, 84, 85] as Array[int])


func test_validation_catches_mistakes() -> void:
	var t := TilesetData.new()
	t.load_dict({"id": "broken", "tiles": [
		{"id": 0, "name": "A", "category": "lava", "kind": "block", "walkable": true, "blocks_sight": false},
		{"id": 1, "name": "B", "category": "prop", "kind": "prop", "walkable": true, "blocks_sight": false}],
		"animations": {"x": {"frames": [7]}},
		"terrains": {"a": {"tiles": [1], "fill": "b"}, "b": {"tiles": [0], "fill": "a"}}}, basic.dir)
	var text := "\n".join(t.validate())
	assert_string_contains(text, "unknown category 'lava'")
	assert_string_contains(text, "animation x uses unknown tile 7")
	assert_string_contains(text, "uses tile 1, which is not a block")
	assert_string_contains(text, "fill loop")


func test_variants_are_stable_and_spread() -> void:
	var seen := {}
	for x in 20:
		for y in 20:
			var t := basic.pick("grass", Vector2i(x, y))
			assert_eq(t, basic.pick("grass", Vector2i(x, y)), "same cell, same tile")
			seen[t] = seen.get(t, 0) + 1
	assert_eq(seen.keys().size(), 3, "all three grass variants show up")
	for t in seen:
		assert_gt(seen[t], 80, "roughly even (%d of 400)" % seen[t])


func test_weights_make_rare_variants_rarer() -> void:
	var rare := 0
	for x in 40:
		for y in 40:
			if basic.pick("dirt", Vector2i(x, y)) == 7:
				rare += 1
	assert_between(rare, 10, 90, "tile 7 has weight 0.3 among ~9.6 (expect ~50 of 1600)")


func test_column_stacks_fill_under_the_top() -> void:
	var art := TileArt.for_tileset(basic)
	var col := art.column("grass", Vector2i(3, 4), 2)
	assert_eq(col.size(), 3, "levels 0, 1 and 2")
	assert_true(basic.terrains.dirt.tiles.has(col[0][0]), "dirt below")
	assert_true(basic.terrains.grass.tiles.has(col[2][0]), "grass on top")
	assert_eq(col[2][1], 2)
	assert_eq(art.column("grass", Vector2i(3, 4), 2, 2).size(), 1, "hidden lower blocks skipped")


func test_image_lines_up_with_the_grid() -> void:
	var art := TileArt.for_tileset(basic)
	var r := art.image_rect(Vector2(100, 50))
	assert_eq(r.size, Vector2(64, 64), "32 px art at 2x")
	assert_eq(r.position, Vector2(100 - 32, 50 - 32), "top face centre (16, 16) in the image")


func test_zone_terrain_bakes_walkability() -> void:
	var z := ZoneDef.new()
	z.id = &"t"
	z.tileset = &"iso_basic"
	z.height_rows = PackedStringArray(["000", "000"])
	z.walk_rows = PackedStringArray(["...", "..."])
	z.terrain_rows = PackedStringArray([".~=", "..?"])
	z.terrain_legend = {".": "grass", "~": "water", "=": "ford"}
	var errors := "\n".join(z.validate_terrain(basic))
	assert_string_contains(errors, "terrain char '?' at (2,1) is not in the legend")
	z.terrain_rows = PackedStringArray([".~=", "..."])
	assert_eq(Array(z.validate_terrain(basic)), [])
	z.bake_walkability(basic)
	assert_eq(Array(z.walk_rows), [".#.", "..."], "water blocks, the ford doesn't")


func test_content_zones_have_valid_terrain() -> void:
	var gf: ZoneDef = ContentDB.zones[&"greenfields"]
	assert_true(gf.has_terrain())
	assert_eq(Array(gf.validate_terrain(basic)), [])


func _prop_zone() -> ZoneDef:
	var z := ZoneDef.new()
	z.id = &"props"
	z.tileset = &"iso_basic"
	z.height_rows = PackedStringArray(["00000"])
	z.walk_rows = PackedStringArray(["....."])
	z.terrain_rows = PackedStringArray(["....."])
	z.terrain_legend = {".": "grass"}
	z.prop_rows = PackedStringArray([".f.B."])
	z.prop_legend = {"f": "flowers", "B": "grey_boulders"}
	return z


func test_props_bake_walkability_and_sight() -> void:
	var z := _prop_zone()
	assert_eq(Array(z.validate_terrain(basic)), [])
	z.bake_walkability(basic)
	assert_eq(Array(z.walk_rows), ["...#."], "flowers can be walked on, a boulder can't")
	assert_eq(Array(z.sight_rows), ["...#."], "the boulder blocks sight")
	var grid := GridModel.from_zone(z)
	assert_true(grid.blocks_sight(Vector2i(3, 0)))
	assert_false(grid.is_walkable(Vector2i(3, 0)))
	assert_true(grid.is_walkable(Vector2i(1, 0)))


func test_sight_blocking_tiles_stop_los_and_projectiles() -> void:
	var z := _prop_zone()
	z.bake_walkability(basic)
	var grid := GridModel.from_zone(z)
	assert_false(LineOfSight.has_los(grid, Vector2i(2, 0), Vector2i(4, 0), 0.5), "behind the boulder")
	assert_true(LineOfSight.has_los(grid, Vector2i(0, 0), Vector2i(2, 0), 0.5), "over the flowers")
	var line := TileGeometry.clip_line(grid, TileGeometry.line8(Vector2i(0, 0), Vector2i(1, 0), 4), 0, 0.5)
	assert_eq(line, [Vector2i(1, 0), Vector2i(2, 0)] as Array[Vector2i], "a shot stops at the boulder")


func test_prop_validation() -> void:
	var z := _prop_zone()
	z.prop_rows = PackedStringArray([".x.."])
	z.prop_legend = {"f": "nope"}
	var text := "\n".join(z.validate_terrain(basic))
	assert_string_contains(text, "prop row 0 has length 4")
	assert_string_contains(text, "prop char 'x' at (1,0) is not in the legend")
	assert_string_contains(text, "unknown prop group nope")
