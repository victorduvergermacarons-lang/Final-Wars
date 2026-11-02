extends GutTest
## Client-side prediction for the local hero and interpolation for everyone
## else (ClientWorld, MoveState): the hero moves at once on its own machine, the
## host's snapshots correct it without visible pops, and other actors are drawn
## smoothly from a snapshot buffer. Latency is simulated by delaying intents.

const ContentDBScript := preload("res://autoload/content_db.gd")

var db
var world: WorldSim
var hero: Hero
var other: Hero
var mirror: ClientWorld
var _in_flight: Array = [] # [deliver_at_tick, intent]
var _tick := 0


func before_all() -> void:
	db = ContentDBScript.new()


func after_all() -> void:
	db.free()


func before_each() -> void:
	var zone: ZoneDef = db.zones[&"greenfields"]
	world = WorldSim.new(zone, db.rules, 7)
	hero = world.add_hero(db.heroes[&"adventurer"])
	other = world.add_hero(db.heroes[&"adventurer"])
	hero.move.place(Vector2i(10, 20))
	other.move.place(Vector2i(15, 20))
	world.step()
	mirror = ClientWorld.new(zone, db.rules, db)
	mirror.local_hero_id = hero.id
	_in_flight.clear()
	_tick = 0
	_sync()


func _sync() -> void:
	mirror.apply_snapshot(Snapshot.capture(world, hero.id))


## One tick of a networked game: the client sends its input and predicts; the
## intent reaches the host `delay` ticks later; the host steps and its snapshot
## arrives right away (the delay stands for the round trip).
func _net_tick(dir: Vector2i, delay: int, face := 0.0) -> void:
	_tick += 1
	var seq := mirror.take_seq()
	mirror.predict_move(seq, dir, face)
	mirror.predict_tick(mirror.now + db.rules.tick_seconds)
	_in_flight.append([_tick + delay, {"type": "move", "dir": dir, "face": face, "seq": seq}])
	for f in _in_flight.filter(func(x): return x[0] <= _tick):
		world.submit(hero.id, f[1])
	_in_flight = _in_flight.filter(func(x): return x[0] > _tick)
	world.step()
	_sync()


func test_the_local_hero_moves_before_the_host_knows() -> void:
	var start := mirror.local_hero().move.pos
	mirror.predict_move(mirror.take_seq(), Vector2i(1, 0), 0.0)
	for i in 4:
		mirror.predict_tick(mirror.now + (i + 1) * db.rules.tick_seconds)
	assert_gt(mirror.local_hero().move.pos.distance_to(start), 0.3, "moved on its own machine")
	assert_eq(hero.move.pos, Vector2(10, 20), "the host hasn't heard yet")


func test_prediction_matches_the_host_with_latency() -> void:
	for i in 30:
		_net_tick(Vector2i(1, -1), 3) # ~150 ms round trip, walking up-right on screen
	var predicted := mirror.local_hero().move.pos
	# The host is behind by the in-flight ticks; the prediction is ahead, so they
	# differ while walking, then meet once the player stops and the inputs land.
	for i in 10:
		_net_tick(Vector2i.ZERO, 3)
	assert_almost_eq(mirror.local_hero().move.pos.x, hero.move.pos.x, 0.05, "same place after settling")
	assert_almost_eq(mirror.local_hero().move.pos.y, hero.move.pos.y, 0.05)
	assert_gt(hero.move.pos.distance_to(Vector2(10, 20)), 2.0, "it really walked")
	assert_lt(predicted.distance_to(hero.move.pos), 1.0)


func test_corrections_fade_instead_of_popping() -> void:
	for i in 10:
		_net_tick(Vector2i(1, 0), 2)
	# The host disagrees by a little (a push the client didn't see).
	hero.move.pos += Vector2(0.3, 0.0)
	world.step()
	var m := mirror.local_hero().move
	var drawn_before := m.position_at(m.time)
	_sync()
	var drawn_after := m.position_at(m.time)
	assert_lt(drawn_after.distance_to(drawn_before), 0.15, "no visible jump on the correction")
	assert_ne(m.smooth_offset, Vector2.ZERO, "the difference fades out")


func test_a_big_disagreement_snaps() -> void:
	_net_tick(Vector2i(1, 0), 1)
	hero.move.place(Vector2i(5, 5)) # a teleport (release, lift, zone edge)
	world.step()
	_sync()
	var m := mirror.local_hero().move
	assert_lt(m.pos.distance_to(Vector2(5, 5)), 0.2, "at the host's place (plus the one input it hasn't seen)")
	assert_eq(m.smooth_offset, Vector2.ZERO, "snapped, not faded across the map")


func test_other_actors_are_drawn_from_a_snapshot_buffer() -> void:
	world.submit(other.id, {"type": "move", "dir": Vector2i(1, 0), "face": 0.0})
	var times: Array[float] = []
	var places: Array[Vector2] = []
	for i in 6:
		world.step()
		_sync()
		times.append(mirror.now)
		places.append(other.move.pos)
	var m := mirror.get_actor(other.id).move
	assert_true(m.buffered)
	# Drawn INTERP_DELAY behind: at (newest + delay) the newest sample shows; half a
	# tick earlier, half way between the last two.
	var newest: float = times.back()
	assert_almost_eq(m.position_at(newest + MoveState.INTERP_DELAY).x, places.back().x, 0.001)
	var half: float = newest + MoveState.INTERP_DELAY - db.rules.tick_seconds * 0.5
	assert_almost_eq(m.position_at(half).x, (places[-1].x + places[-2].x) / 2.0, 0.001)
	assert_false(mirror.local_hero().move.buffered, "the local hero is predicted, not buffered")


func test_a_glide_the_host_drives_is_not_predicted() -> void:
	hero.move.begin(Vector2i(13, 20), world.now, 0.5) # e.g. a knockback
	world.step()
	_sync()
	mirror.predict_move(mirror.take_seq(), Vector2i(-1, 0), 0.0)
	var before := mirror.local_hero().move.pos
	mirror.predict_tick(mirror.now + db.rules.tick_seconds)
	assert_eq(mirror.local_hero().move.pos, before, "the host moves it; input waits")
