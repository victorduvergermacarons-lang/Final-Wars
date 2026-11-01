extends GutTest

const WALK := 0.25

var move: MoveState
var cd: Cooldowns


func before_each() -> void:
	move = MoveState.new(Vector2i(2, 2))
	cd = Cooldowns.new()


func test_a_glide_is_moving_until_it_arrives() -> void:
	# Free movement has no step cooldown; glides (forced moves) last their time.
	move.begin(Vector2i(3, 2), 0.0, WALK)
	assert_true(move.is_moving(0.2), "still gliding")
	assert_false(move.is_moving(0.25), "arrived")


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
