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
