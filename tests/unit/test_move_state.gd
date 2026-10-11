extends GutTest

const WALK := 0.25

var move: MoveState
var cd: Cooldowns


func before_each() -> void:
	move = MoveState.new(Vector2i(2, 2))
	cd = Cooldowns.new()


func test_out_of_combat_has_no_step_cooldown_only_walk_time() -> void:
	move.begin(Vector2i(3, 2), 0.0, WALK)
	cd.trigger_step(0.0, 5.0) # a leftover combat step cooldown must not matter
	assert_false(move.can_start_step(false, cd, 0.2), "still walking")
	assert_true(move.can_start_step(false, cd, 0.25), "arrived: step again immediately")


func test_in_combat_needs_arrival_and_step_cooldown() -> void:
	move.begin(Vector2i(3, 2), 0.0, WALK)
	cd.trigger_step(0.0, 0.5)
	assert_false(move.can_start_step(true, cd, 0.3), "arrived but step cooldown running")
	assert_true(move.can_start_step(true, cd, 0.5))


func test_consecutive_steps_chain_tiles() -> void:
	move.begin(Vector2i(3, 2), 0.0, WALK)
	move.begin(Vector2i(4, 2), 0.25, WALK)
	assert_eq(move.from_tile, Vector2i(3, 2))
	assert_eq(move.to_tile, Vector2i(4, 2))


func test_progress_for_view_interpolation() -> void:
	move.begin(Vector2i(3, 2), 1.0, WALK)
	assert_eq(move.progress(1.0), 0.0)
	assert_almost_eq(move.progress(1.125), 0.5, 0.0001)
	assert_eq(move.progress(9.0), 1.0)


func test_place_snaps_without_walking() -> void:
	move.begin(Vector2i(3, 2), 0.0, WALK)
	move.place(Vector2i(0, 0))
	assert_false(move.is_moving(0.1))
	assert_eq(move.from_tile, Vector2i(0, 0))
	assert_eq(move.progress(0.1), 1.0)


func test_dict_round_trip() -> void:
	move.begin(Vector2i(3, 2), 1.0, WALK)
	var copy := MoveState.from_dict(move.to_dict())
	assert_eq(copy.from_tile, Vector2i(2, 2))
	assert_eq(copy.to_tile, Vector2i(3, 2))
	assert_almost_eq(copy.progress(1.125), 0.5, 0.0001)
