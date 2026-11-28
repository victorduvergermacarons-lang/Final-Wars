extends GutTest
## Water physics phase 1 (2026-11-28): the rope's shadow darkens what it falls on
## (black at SHADOW_DARKEN, each pixel once), and the terrain cache puts back the bare
## ground in front of a tile it draws again, so a wall's lower faces never show.


func test_the_shadow_darkens_two_ground_colours_each_by_its_own_amount() -> void:
	var s: WaterRopeSettings = load("res://content/effects/water_rope_settings.tres")
	assert_almost_eq(s.SHADOW_DARKEN, 0.3, 0.001)
	var shade := Color(0, 0, 0, s.SHADOW_DARKEN)
	var grass := Color("6FAE3C")
	var stone := Color("8A8F98")
	var on_grass := grass.blend(shade)
	var on_stone := stone.blend(shade)
	assert_ne(on_grass, on_stone, "a darker green and a darker grey")
	for pair in [[grass, on_grass], [stone, on_stone]]:
		assert_almost_eq(pair[1].r, pair[0].r * 0.7, 0.01)
		assert_almost_eq(pair[1].g, pair[0].g * 0.7, 0.01)
		assert_almost_eq(pair[1].b, pair[0].b * 0.7, 0.01)


func test_the_ground_in_front_of_a_tile_drawn_again_is_put_back() -> void:
	var zone := ZoneDef.new()
	zone.id = &"t"
	zone.height_rows = PackedStringArray(["000000", "000000", "003000", "000000", "000000", "000000"])
	zone.walk_rows = PackedStringArray(["......", "......", "..#...", "......", "......", "......"])
	zone.hero_spawns = [Vector2i(0, 0)]
	var grid := GridModel.from_zone(zone)
	var view := WorldView.new()
	view._max_depth = 12
	view._max_height = 3
	view._zone = zone # bare ground isn't drawn again over actors (WorldView._covers)
	var wall := Vector2i(2, 2)
	var c := Iso.to_screen(Vector2(wall), 0.0)
	var cluster := {"rect": Rect2(c - Vector2(40, 60), Vector2(80, 90)), "depth": 0, "h": 0, "cover": {}, "patch": {}}
	view._collect_cover(grid, cluster, {})
	assert_true(cluster.cover.has(wall), "the tall tile is drawn again over what stands behind it")
	assert_true(cluster.patch.has(wall), "…followed by the ground in front of it")
	var front: Array = cluster.patch.get(wall, [])
	for d in [Vector2i(1, 0), Vector2i(0, 1)]:
		assert_true(front.has(wall + d), "the bare tile at %s" % [wall + d])
	view.free()
