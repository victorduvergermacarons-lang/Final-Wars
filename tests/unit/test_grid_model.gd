extends GutTest


func _zone(heights: Array, walk: Array) -> ZoneDef:
	var z := ZoneDef.new()
	z.id = &"test"
	z.height_rows = PackedStringArray(heights)
	z.walk_rows = PackedStringArray(walk)
	return z


func test_from_zone_parses_heights_and_walkability() -> void:
	var g := GridModel.from_zone(_zone(["01a", "234"], ["..#", "..."]))
	assert_not_null(g)
	assert_eq(g.width, 3)
	assert_eq(g.depth, 2)
	assert_eq(g.height_at(Vector2i(1, 0)), 1)
	assert_eq(g.height_at(Vector2i(2, 0)), 10, "'a' is height 10")
	assert_eq(g.height_at(Vector2i(2, 1)), 4)
	assert_false(g.is_walkable(Vector2i(2, 0)))
	assert_true(g.is_walkable(Vector2i(0, 1)))


func test_zone_validation_reports_bad_rows() -> void:
	var z := _zone(["00", "0"], [".."])
	z.graveyards = [Vector2i(5, 5)]
	var errors := z.validate()
	assert_eq(errors.size(), 3, str(errors))


func test_from_zone_rejects_invalid_zone() -> void:
	assert_null(GridModel.from_zone(_zone(["0?"], [".."])))
	assert_push_error("Invalid zone")


func test_out_of_bounds_is_not_walkable() -> void:
	var g := GridModel.new(2, 2)
	assert_false(g.is_walkable(Vector2i(-1, 0)))
	assert_false(g.is_walkable(Vector2i(2, 0)))
	assert_eq(g.height_at(Vector2i(9, 9)), 0)


func test_distance_is_manhattan() -> void:
	assert_eq(GridModel.distance(Vector2i(0, 0), Vector2i(3, -2)), 5)


func test_can_step_respects_jump_when_climbing() -> void:
	var g := GridModel.new(3, 1)
	g.set_tile(Vector2i(1, 0), 2, true)
	assert_false(g.can_step(Vector2i(0, 0), Vector2i(1, 0), 1), "rise 2 > jump 1")
	assert_true(g.can_step(Vector2i(0, 0), Vector2i(1, 0), 2), "rise 2 <= jump 2")


func test_can_step_drops_freely_by_default_but_honours_max_drop() -> void:
	var g := GridModel.new(2, 1)
	g.set_tile(Vector2i(0, 0), 5, true)
	assert_true(g.can_step(Vector2i(0, 0), Vector2i(1, 0), 0))
	assert_false(g.can_step(Vector2i(0, 0), Vector2i(1, 0), 0, 3))


func test_can_step_rejects_non_adjacent_blocked_and_out_of_bounds() -> void:
	var g := GridModel.new(3, 3)
	g.set_tile(Vector2i(1, 0), 0, false)
	assert_false(g.can_step(Vector2i(0, 0), Vector2i(1, 1), 9), "diagonal")
	assert_false(g.can_step(Vector2i(0, 0), Vector2i(2, 0), 9), "two tiles")
	assert_false(g.can_step(Vector2i(0, 0), Vector2i(1, 0), 9), "blocked")
	assert_false(g.can_step(Vector2i(0, 0), Vector2i(-1, 0), 9), "out of bounds")


func test_height_advantage() -> void:
	var g := GridModel.new(2, 1)
	g.set_tile(Vector2i(0, 0), 3, true)
	assert_eq(g.height_advantage(Vector2i(0, 0), Vector2i(1, 0)), 3)
	assert_eq(g.height_advantage(Vector2i(1, 0), Vector2i(0, 0)), -3)
