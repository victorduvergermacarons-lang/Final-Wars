extends GutTest
## Host world → snapshot → client mirror, and client-side step prediction.

const ContentDBScript := preload("res://autoload/content_db.gd")

var db
var world: WorldSim
var hero: Hero
var other: Hero
var mirror: ClientWorld


func before_all() -> void:
	db = ContentDBScript.new()


func after_all() -> void:
	db.free()


func before_each() -> void:
	var zone: ZoneDef = db.zones[&"greenfields"]
	world = WorldSim.new(zone, db.rules, 7)
	hero = world.add_hero(db.heroes[&"adventurer"])
	hero.display_name = "Ann"
	other = world.add_hero(db.heroes[&"adventurer"])
	hero.move.place(Vector2i(10, 20)) # open meadow, room to walk up
	other.move.place(Vector2i(15, 20))
	mirror = ClientWorld.new(zone, db.rules, db)
	mirror.local_hero_id = hero.id


func _sync() -> void:
	mirror.apply_snapshot(Snapshot.capture(world, hero.id))


func test_snapshot_rebuilds_every_actor() -> void:
	_sync()
	assert_eq(mirror.actors().size(), world.ctx.actors.size())
	var h := mirror.local_hero()
	assert_eq(h.display_name, "Ann")
	assert_eq(h.tile(), hero.tile())
	assert_true(h.stats.equals(hero.stats))
	assert_true(h.base_stats.equals(hero.base_stats))
	assert_true(h.growth.equals(hero.growth))
	assert_eq(h.available_abilities().map(func(a): return a.id), [&"strike", &"heal", &"resurrect"])
	var wolf := mirror.get_actor(world.enemies()[0].id) as Enemy
	assert_eq(wolf.def.id, &"wolf")
	assert_eq(wolf.spawn_tile, world.enemies()[0].spawn_tile)


func test_snapshot_carries_progress_cooldowns_and_buffs() -> void:
	hero.ap[&"strike"] = 20
	hero.mastered[&"heal"] = db.abilities[&"heal"]
	hero.bag.add(db.items[&"shield"])
	world.submit(hero.id, {"type": "equip", "bag_index": hero.bag.index_of(db.items[&"shield"])})
	world.step()
	world.submit(hero.id, {"type": "cast", "ability": &"block", "target": hero.id})
	world.step()
	_sync()
	var h := mirror.local_hero()
	assert_eq(h.ap[&"strike"], 20)
	assert_true(h.is_mastered(&"heal"))
	assert_eq(h.equipped_in(EquipSlot.Id.OFF_HAND).id, &"shield")
	assert_gt(h.cooldowns.ability_remaining(&"block", mirror.now), 0.0)
	assert_eq(h.current_stats(mirror.now).phys_def, hero.current_stats(world.now).phys_def)


func test_snapshot_survives_variant_encoding() -> void:
	# What actually crosses the wire: encode/decode like an RPC would.
	var bytes := var_to_bytes(Snapshot.capture(world, hero.id))
	mirror.apply_snapshot(bytes_to_var(bytes))
	assert_eq(mirror.local_hero().tile(), hero.tile())


func test_actors_missing_from_snapshot_are_removed() -> void:
	_sync()
	world.remove_hero(other.id)
	_sync()
	assert_null(mirror.get_actor(other.id))


func test_predicted_step_moves_immediately() -> void:
	_sync()
	var start := hero.tile()
	var to := start + Vector2i.UP
	assert_true(mirror.predict_step(mirror.take_seq(), to, mirror.now))
	assert_eq(mirror.local_hero().tile(), to, "moved before the host knows")


func test_unacknowledged_step_survives_a_snapshot() -> void:
	_sync()
	var to := hero.tile() + Vector2i.UP
	mirror.predict_step(mirror.take_seq(), to, mirror.now)
	world.step() # host hasn't received the intent yet
	_sync()
	assert_eq(mirror.local_hero().tile(), to)
	assert_eq(mirror.pending_step_count(), 1)


func test_acknowledged_step_matches_host() -> void:
	_sync()
	var to := hero.tile() + Vector2i.UP
	var seq := mirror.take_seq()
	mirror.predict_step(seq, to, mirror.now)
	world.submit(hero.id, {"type": "step", "to": to, "seq": seq})
	world.step()
	_sync()
	assert_eq(hero.tile(), to)
	assert_eq(mirror.local_hero().tile(), to)
	assert_eq(mirror.pending_step_count(), 0)


func test_rejected_step_snaps_back() -> void:
	_sync()
	var start := hero.tile()
	var to := start + Vector2i.UP
	var seq := mirror.take_seq()
	mirror.predict_step(seq, to, mirror.now)
	# Host refuses (something moved into the tile first).
	other.move.place(to)
	world.submit(hero.id, {"type": "step", "to": to, "seq": seq})
	world.step()
	_sync()
	assert_eq(hero.tile(), start)
	assert_eq(mirror.local_hero().tile(), start, "corrected to the host's position")


func test_illegal_steps_are_not_predicted() -> void:
	_sync()
	var h := mirror.local_hero()
	assert_false(mirror.predict_step(1, h.tile() + Vector2i(2, 0), mirror.now), "not adjacent")
	assert_false(mirror.predict_step(2, other.tile(), mirror.now) and GridModel.distance(h.tile(), other.tile()) == 1)


func test_prediction_queue_is_bounded() -> void:
	_sync()
	var p := hero.tile()
	assert_true(mirror.predict_step(1, p + Vector2i.UP, mirror.now))
	assert_true(mirror.predict_step(2, p + Vector2i.UP * 2, mirror.now))
	assert_false(mirror.predict_step(3, p + Vector2i.UP * 3, mirror.now))


func test_facing_is_replicated_and_predicted() -> void:
	hero.face(Vector2i.LEFT)
	_sync()
	assert_eq(mirror.local_hero().facing, Vector2i.LEFT)
	var seq := mirror.take_seq()
	mirror.predict_face(seq, Vector2i.RIGHT)
	_sync() # host hasn't processed it yet
	assert_eq(mirror.local_hero().facing, Vector2i.RIGHT, "prediction survives the snapshot")
	world.submit(hero.id, {"type": "face", "dir": Vector2i.RIGHT, "seq": seq})
	world.step()
	_sync()
	assert_eq(mirror.local_hero().facing, Vector2i.RIGHT)
	assert_eq(mirror.pending_step_count(), 0)


func test_other_heroes_private_data_is_not_sent() -> void:
	other.gold = 500
	other.bag.add(db.items[&"staff"])
	var snap := Snapshot.capture(world, hero.id)
	for d in snap.actors:
		if d.id == other.id:
			assert_false(d.has("private"), "no bag, gold, AP or quests for other players")
			assert_true(d.has("eq"), "equipment and level stay visible")
		elif d.id == hero.id:
			assert_true(d.has("private"))
	hero.gold = 42
	_sync()
	assert_eq(mirror.local_hero().gold, 42)
	assert_eq(mirror.get_actor(other.id).gold, 0, "never received")


func test_world_flags_reach_clients() -> void:
	_sync()
	assert_eq(mirror.world_flags, {})
	world.world_flags["grizzlehide_slain"] = true
	_sync()
	assert_eq(mirror.world_flags, {"grizzlehide_slain": true})
