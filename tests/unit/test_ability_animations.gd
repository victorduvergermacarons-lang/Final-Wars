extends GutTest
## The ability changes of 2026-11-21 (with the new hero animations): Rock Throw's two
## presses (the rock rises and waits while the hero stands, the second press throws
## it on earth_punch's strike, it lands with an impact; no press: it throws itself),
## Fire Punch hitting as the key is pressed, Water Whip's window from 0.45 s and its
## hit on the lash's snap, and the effects sent to every player.

var world: World
var sim: WorldSim
var hero: Hero
var wolf: Enemy


func before_each() -> void:
	ContentDB.rules.timing_bars_enabled = true
	world = World.new(ContentDB.zones.values(), ContentDB.rules, 5, &"town", ContentDB.quests)
	hero = world.add_saved_hero(CharacterData.new_character("Rook", ContentDB.heroes[&"adventurer"]), ContentDB)
	for id in [&"E01", &"W02", &"F01", &"F02"]:
		hero.mastered[id] = ContentDB.abilities[id]
	hero.mana = hero.current_stats(0.0).mana
	sim = world.zone_of(hero.id)
	for d in GridModel.DIRECTIONS:
		var t: Vector2i = hero.tile() + d
		if sim.grid.in_bounds(t) and sim.grid.is_walkable(t) and not sim.is_occupied(t) \
				and absi(sim.grid.height_at(t) - sim.grid.height_at(hero.tile())) <= 1:
			wolf = sim.add_enemy(ContentDB.enemies[&"wolf"], t)
			break
	assert_not_null(wolf)
	wolf.threat.add(hero.id, 1.0) # already fighting: it won't wander off mid-test
	world.step()


func _since_start() -> float:
	return world.now - float(hero.casting.start)


static func _of(events: Array, type: String, ability: StringName = &"") -> Array:
	return events.filter(func(e): return e.type == type and (ability == &"" or e.get("ability", &"") == ability))


# --- Rock Throw -------------------------------------------------------------------

func test_rock_throw_first_press_raises_the_rock_and_roots_the_hero() -> void:
	world.submit(hero.id, {"type": "cast", "ability": &"E01", "target": -1, "aim": wolf.move.pos})
	world.step()
	assert_eq(hero.casting.get("kind", ""), "timing", "the rock rises and waits (a 3 s bar)")
	assert_eq(hero.casting.ability.timing_bar.seconds, 3.0)
	var at := hero.move.pos
	for i in 10:
		world.submit(hero.id, {"type": "move", "dir": Vector2i(0, -1), "face": 0.0})
		world.step()
	assert_almost_eq(hero.move.pos.distance_to(at), 0.0, 0.01, "the hero can't move while the rock is up")
	assert_false(hero.casting.is_empty(), "walking doesn't drop it")
	assert_eq(hero.cooldowns.ability_remaining(&"E01", world.now), 0.0, "no cooldown before the throw")


func test_rock_throw_second_press_throws_on_the_strike_frame() -> void:
	var hp := wolf.hp
	world.submit(hero.id, {"type": "cast", "ability": &"E01", "target": -1, "aim": wolf.move.pos})
	world.step()
	world.advance(1.0 - _since_start())
	world.submit(hero.id, {"type": "timing_press", "at": 1.0, "aim": wolf.move.pos})
	var events := world.step()
	assert_eq(_of(events, "release", &"E01").size(), 1, "the punch starts for every player")
	assert_true(sim.pending_hits().filter(func(h): return h.ability == &"E01").is_empty(),
			"the rock hasn't left the fist yet")
	events = world.advance(ContentDB.abilities[&"E01"].release_delay_seconds + 0.05)
	assert_eq(_of(events, "cast", &"E01").size(), 1, "on earth_punch's strike frame it flies")
	assert_gt(hero.cooldowns.ability_remaining(&"E01", world.now), 0.0, "the cooldown starts on the throw")
	var flight: Array = sim.pending_hits().filter(func(h): return h.ability == &"E01")
	assert_eq(flight.size(), 1, "the rock in flight, for every player")
	assert_lt(float(flight[0].start), float(flight[0].at), "with its start and landing times")
	assert_almost_eq(flight[0].to.distance_to(wolf.move.pos), 0.0, 0.6, "toward the cursor")
	events = world.advance(ContentDB.abilities[&"E01"].arc_seconds + 0.1)
	assert_lt(wolf.hp, hp, "damage where it lands")
	assert_eq(_of(events, "fx", &"E01").map(func(e): return e.fx), [&"rock_impact"], "and the impact")


func test_rock_throw_throws_itself_when_the_bar_ends() -> void:
	var hp := wolf.hp
	world.submit(hero.id, {"type": "cast", "ability": &"E01", "target": -1, "aim": wolf.move.pos})
	world.step()
	var events := world.advance(3.0 + ContentDB.rules.timing_press_grace_seconds + 0.1)
	assert_eq(_of(events, "timing_result", &"E01")[0].grade, "miss", "no press: it goes off anyway, softer")
	events.append_array(world.advance(ContentDB.abilities[&"E01"].release_delay_seconds
			+ ContentDB.abilities[&"E01"].arc_seconds + 0.2))
	assert_lt(wolf.hp, hp, "it threw itself")
	assert_gt(hero.cooldowns.ability_remaining(&"E01", world.now), 0.0)


# --- Fire Punch, Fire Kick ------------------------------------------------------

func test_fire_punch_hits_as_the_key_is_pressed() -> void:
	assert_null(ContentDB.abilities[&"F01"].timing_bar, "no bar")
	var hp := wolf.hp
	world.submit(hero.id, {"type": "cast", "ability": &"F01", "target": wolf.id})
	var events := world.step()
	assert_true(hero.casting.is_empty(), "no cast, no wind-up")
	assert_lt(wolf.hp, hp, "the damage lands the same tick")
	assert_eq(_of(events, "cast", &"F01").size(), 1)
	assert_almost_eq(hero.cooldowns.ability_remaining(&"F01", world.now), 2.0 - ContentDB.rules.tick_seconds, 0.06,
			"its 2 s cooldown")
	assert_gt(hero.cooldowns.gcd_remaining(world.now), 0.0, "and the global cooldown")


func test_fire_kick_sends_its_flame_arc_to_every_player() -> void:
	world.submit(hero.id, {"type": "cast", "ability": &"F02", "target": wolf.id})
	world.step()
	world.advance(0.9 - _since_start())
	world.submit(hero.id, {"type": "timing_press", "at": 0.9})
	var events := world.step()
	var fx := _of(events, "fx", &"F02")
	assert_eq(fx.size(), 1)
	assert_eq(fx[0].fx, &"fire_arc")
	assert_almost_eq(fx[0].to.distance_to(wolf.move.pos), 0.0, 0.01, "toward the target")


# --- Water Whip -------------------------------------------------------------------

func test_water_whip_is_thrown_at_once_and_hits_on_the_snap() -> void:
	assert_null(ContentDB.abilities[&"W02"].timing_bar, "instant since 2026-11-28")
	# Water to bend: a pouch and the stance 1 rope.
	hero.bag.add(ContentDB.items[Hero.WATER_POUCH])
	hero.water = 200
	hero.stance_tree = "Water"
	hero.stance = 1
	hero.stance_water = 24
	var hp := wolf.hp
	world.submit(hero.id, {"type": "cast", "ability": &"W02", "target": wolf.id})
	var events := world.step()
	assert_eq(_of(events, "fx", &"W02").map(func(e): return e.fx), [&"water_whip"], "the rope thrown at once")
	assert_eq(wolf.hp, hp, "not yet: the lash is still curling")
	var fx: FxDef = ContentDB.effects[&"water_whip"]
	assert_almost_eq(ContentDB.abilities[&"W02"].release_delay_seconds, fx.hit_frame / fx.fps, 0.001)
	world.advance(ContentDB.abilities[&"W02"].release_delay_seconds + 0.05)
	assert_lt(wolf.hp, hp, "the hit lands on the lash's snap")


func test_air_effects_are_see_through_and_point_at_their_target() -> void:
	for id in [&"air_palm_spiral", &"air_gust_spiral"]:
		var fx: FxDef = ContentDB.effects[id]
		assert_almost_eq(fx.alpha, 0.6, 0.001, "%s at 60%%" % id)
		assert_true(fx.rotate)
	assert_eq(ContentDB.abilities[&"A01"].fx_cast, &"air_palm_spiral")
	assert_eq(ContentDB.abilities[&"A02"].fx_cast, &"gust_wind", "Gust: a front since phase 4 (the spiral is gone)")
