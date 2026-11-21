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


## A knockback on the host, seen by a client: the pushed actor must follow the
## snapshots once the push is over (it used to stay drawn where the push left it).
func test_a_finished_push_is_not_sent_and_clients_keep_following() -> void:
	var host := MoveState.new(Vector2i(0, 0))
	host.begin(Vector2(2, 0), 0.0, 0.3)
	host.update_glide(0.15)
	assert_true(host.to_dict().has("glide"), "sent while it lasts")
	host.update_glide(0.4)
	assert_false(host.to_dict().has("glide"), "not once it's over")
	# The client's copy of that actor, fed a snapshot per tick: the push, then a walk.
	var client := MoveState.new(Vector2i(0, 0))
	client.buffered = true
	var t := 0.0
	host = MoveState.new(Vector2i(0, 0))
	host.begin(Vector2(2, 0), 0.0, 0.3)
	while t < 1.0:
		t += 0.05
		host.update_glide(t)
		if not host.gliding:
			host.pos += Vector2(0, 0.15) # walking on after the push
		client.apply_dict(host.to_dict(), t)
	var drawn := client.position_at(t)
	assert_gt(drawn.y, 0.5, "drawn walking on, not frozen at the push's end: %s" % drawn)
