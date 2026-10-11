extends GutTest

const TOL := 1.0


func test_flat_ground_is_clear() -> void:
	var g := GridModel.new(6, 6)
	assert_true(LineOfSight.has_los(g, Vector2i(0, 0), Vector2i(5, 3), TOL))


func test_adjacent_and_same_tile_always_clear() -> void:
	var g := GridModel.new(2, 1)
	g.set_tile(Vector2i(1, 0), 9, true)
	assert_true(LineOfSight.has_los(g, Vector2i(0, 0), Vector2i(1, 0), TOL))
	assert_true(LineOfSight.has_los(g, Vector2i(0, 0), Vector2i(0, 0), TOL))


func test_low_bump_within_tolerance_does_not_block() -> void:
	var g := GridModel.new(3, 1)
	g.set_tile(Vector2i(1, 0), 1, true)
	assert_true(LineOfSight.has_los(g, Vector2i(0, 0), Vector2i(2, 0), TOL))


func test_tall_wall_blocks_both_ways() -> void:
	var g := GridModel.new(3, 1)
	g.set_tile(Vector2i(1, 0), 2, false)
	assert_false(LineOfSight.has_los(g, Vector2i(0, 0), Vector2i(2, 0), TOL))
	assert_false(LineOfSight.has_los(g, Vector2i(2, 0), Vector2i(0, 0), TOL))


func test_high_ground_sees_over_wall() -> void:
	# Shooter on a height-4 tower, wall of 2 halfway, target at 0: line is at 2 there.
	var g := GridModel.new(3, 1)
	g.set_tile(Vector2i(0, 0), 4, true)
	g.set_tile(Vector2i(1, 0), 2, false)
	assert_true(LineOfSight.has_los(g, Vector2i(0, 0), Vector2i(2, 0), TOL))


func test_tolerance_is_configurable() -> void:
	var g := GridModel.new(3, 1)
	g.set_tile(Vector2i(1, 0), 1, true)
	assert_false(LineOfSight.has_los(g, Vector2i(0, 0), Vector2i(2, 0), 0.0))


func test_tiles_between_straight_and_diagonal() -> void:
	assert_eq(LineOfSight.tiles_between(Vector2i(0, 0), Vector2i(3, 0)), [[Vector2i(1, 0)], [Vector2i(2, 0)]])
	# Exact diagonal passes through corners: corner pairs plus the diagonal tiles.
	var d := LineOfSight.tiles_between(Vector2i(0, 0), Vector2i(2, 2))
	assert_eq(d, [
		[Vector2i(1, 0), Vector2i(0, 1)],
		[Vector2i(1, 1)],
		[Vector2i(2, 1), Vector2i(1, 2)],
	])


func test_corner_blocks_only_if_both_sides_block() -> void:
	var g := GridModel.new(2, 2)
	g.set_tile(Vector2i(1, 0), 5, false)
	assert_true(LineOfSight.has_los(g, Vector2i(0, 0), Vector2i(1, 1), TOL), "one side open")
	g.set_tile(Vector2i(0, 1), 5, false)
	assert_false(LineOfSight.has_los(g, Vector2i(0, 0), Vector2i(1, 1), TOL), "both sides walled")
