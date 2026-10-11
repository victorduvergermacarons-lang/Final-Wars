extends GutTest


func _grid(heights: Array, walk: Array) -> GridModel:
	var z := ZoneDef.new()
	z.height_rows = PackedStringArray(heights)
	z.walk_rows = PackedStringArray(walk)
	return GridModel.from_zone(z)


func test_straight_line_path() -> void:
	var g := GridModel.new(5, 1)
	var path := Pathfinder.find_path(g, Vector2i(0, 0), Vector2i(4, 0), 1)
	assert_eq(path.size(), 5)
	assert_eq(path[0], Vector2i(0, 0))
	assert_eq(path[4], Vector2i(4, 0))


func test_start_equals_goal() -> void:
	var g := GridModel.new(2, 2)
	assert_eq(Pathfinder.find_path(g, Vector2i(1, 1), Vector2i(1, 1), 1), [Vector2i(1, 1)] as Array[Vector2i])


func test_paths_around_walls_with_shortest_length() -> void:
	var g := _grid(
		["00000", "00000", "00000"],
		["..#..", "..#..", "....."])
	var path := Pathfinder.find_path(g, Vector2i(0, 0), Vector2i(4, 0), 1)
	assert_eq(path.size(), 9, "down 2, across 4, up 2")
	for p in path:
		assert_true(g.is_walkable(p))
	for i in range(1, path.size()):
		assert_eq(GridModel.distance(path[i - 1], path[i]), 1)


func test_cliff_forces_detour_to_ramp() -> void:
	# Plateau at height 3 on the right; a ramp 1-2-3 on the bottom row.
	var g := _grid(
		["0333", "0333", "0123"],
		["....", "....", "...."])
	var path := Pathfinder.find_path(g, Vector2i(0, 0), Vector2i(3, 0), 1)
	assert_true(path.has(Vector2i(1, 2)) and path.has(Vector2i(2, 2)), "uses the ramp: %s" % [path])
	var direct := Pathfinder.find_path(g, Vector2i(0, 0), Vector2i(3, 0), 3)
	assert_eq(direct.size(), 4, "jump 3 climbs the cliff directly")


func test_drop_is_one_way() -> void:
	var g := _grid(["30"], [".."])
	assert_eq(Pathfinder.find_path(g, Vector2i(0, 0), Vector2i(1, 0), 1).size(), 2, "can drop")
	assert_true(Pathfinder.find_path(g, Vector2i(1, 0), Vector2i(0, 0), 1).is_empty(), "can't climb back")


func test_unreachable_returns_empty() -> void:
	var g := _grid(["000"], [".#."])
	assert_true(Pathfinder.find_path(g, Vector2i(0, 0), Vector2i(2, 0), 9).is_empty())


func test_blocked_tiles_are_avoided_but_goal_may_be_occupied() -> void:
	var g := GridModel.new(3, 2)
	var blocked := {Vector2i(1, 0): true, Vector2i(2, 0): true}
	var path := Pathfinder.find_path(g, Vector2i(0, 0), Vector2i(2, 0), 1, blocked)
	assert_eq(path, [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(2, 0)] as Array[Vector2i])


func test_search_limit_gives_up() -> void:
	var g := GridModel.new(30, 30)
	assert_true(Pathfinder.find_path(g, Vector2i(0, 0), Vector2i(29, 29), 1, {}, -1, 10).is_empty())


func test_results_are_deterministic() -> void:
	var g := GridModel.new(6, 6)
	var a := Pathfinder.find_path(g, Vector2i(0, 0), Vector2i(5, 5), 1)
	var b := Pathfinder.find_path(g, Vector2i(0, 0), Vector2i(5, 5), 1)
	assert_eq(a, b)
