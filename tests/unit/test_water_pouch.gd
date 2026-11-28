extends GutTest
## The Water Pouch and the Water stance 1 rope (2026-11-26): 200 water points carried
## at the hip; the orbit takes 24 away from water, each Water Whip 4; water tiles are
## an unlimited source; E at water fills the pouch; no water, no orbit and no whip.

var world: World
var sim: WorldSim
var hero: Hero


func before_each() -> void:
	ContentDB.rules.timing_bars_enabled = false
	ContentDB.rules.party_scaling = false
	world = World.new(ContentDB.zones.values(), ContentDB.rules, 5, &"town", ContentDB.quests)
	var data := CharacterData.new_character("Mira", ContentDB.heroes[&"adventurer"], ContentDB.elements[&"water"])
	hero = world.add_saved_hero(data, ContentDB)
	sim = world.zone_of(hero.id)
	TreeRules.master(hero, ContentDB.abilities[&"W02"])
	world.step()


func after_each() -> void:
	ContentDB.rules.timing_bars_enabled = true
	ContentDB.rules.party_scaling = true


## A walkable tile at least `min_d` and at most `max_d` tiles from water.
func _tile_from_water(min_d: float, max_d: float) -> Vector2i:
	var idx := WaterTiles.of(sim.zone)
	for y in sim.grid.depth:
		for x in sim.grid.width:
			var t := Vector2i(x, y)
			if not sim.grid.is_walkable(t):
				continue
			var w = WaterTiles.nearest(idx, Vector2(t), max_d)
			if w != null and Vector2(t).distance_to(Vector2(w)) >= min_d \
					and WaterTiles.nearest(idx, Vector2(t), min_d - 0.01) == null:
				return t
	return Vector2i(-1, -1)


func _go(t: Vector2i) -> void:
	assert_ne(t, Vector2i(-1, -1), "a place found")
	hero.move.place(t)
	hero.move.ground_h = sim.grid.height_at(t)
	world.step()


func _stance(n: int) -> void:
	world.submit(hero.id, {"type": "stance", "tree": "Water" if n > 0 else "", "stance": n})
	world.step()


## Stance 1 fills a point every 8.5 frames: 24 points take 3.4 s.
func _fill_rope() -> void:
	world.advance(24 * 8.5 / 60.0 + 0.1)


func _cast(target: Actor) -> Array:
	world.submit(hero.id, {"type": "cast", "ability": &"W02", "target": target.id})
	return world.step()


func test_water_heroes_start_with_a_full_pouch() -> void:
	assert_true(hero.has_water_pouch())
	assert_eq(hero.water, 200)


func test_stance_1_takes_24_from_the_pouch_and_gives_them_back() -> void:
	_go(_tile_from_water(8.0, 40.0))
	assert_false(hero.near_water)
	_stance(1)
	assert_eq(hero.stance_water, 0, "nothing at once: it fills by the refill")
	_fill_rope()
	assert_eq(hero.stance_water, 24)
	assert_true(hero.rope)
	assert_eq(hero.water, 176)
	_stance(0)
	assert_false(hero.rope)
	assert_eq(hero.stance_water, 0)
	assert_eq(hero.water, 200, "back into the pouch")


func test_near_water_the_stance_is_free() -> void:
	_go(_tile_from_water(1.0, 2.5))
	assert_true(hero.near_water)
	_stance(1)
	_fill_rope()
	assert_eq(hero.stance_water, 24)
	assert_eq(hero.water, 200)


func test_a_short_pouch_makes_a_short_rope_and_no_water_no_whip() -> void:
	_go(_tile_from_water(8.0, 40.0))
	hero.water = 10
	_stance(1)
	_fill_rope()
	assert_eq(hero.stance_water, 10, "what the pouch had")
	assert_eq(hero.water, 0)
	hero.stance_water = 3
	assert_false(AbilityResolver.has_water(hero, ContentDB.abilities[&"W02"]), "fewer than its 4")
	var wolf := sim.add_enemy(ContentDB.enemies[&"wolf"], hero.tile() + Vector2i(2, 0))
	var events := _cast(wolf)
	assert_true(events.any(func(e): return e.type == "rejected" and e.get("reason", "") == "no_water"),
			"refused: not enough water")


func test_the_whip_throws_the_whole_rope_and_lands_half_a_second_later() -> void:
	ContentDB.rules.timing_bars_enabled = true # instant since 2026-11-28 anyway
	_go(_tile_from_water(8.0, 40.0))
	_stance(1)
	_fill_rope()
	var wolf := sim.add_enemy(ContentDB.enemies[&"wolf"], hero.tile() + Vector2i(2, 0))
	var hp := wolf.hp
	var events := _cast(wolf)
	assert_true(events.any(func(e): return e.type == "release" and e.ability == &"W02"), "thrown at once")
	assert_eq(hero.stance_water, 0, "the whole rope is out")
	assert_eq(int(hero.water_out.points), 24)
	assert_almost_eq(ContentDB.abilities[&"W02"].release_delay_seconds, 0.5, 0.001)
	world.advance(0.42)
	assert_eq(wolf.hp, hp, "not yet")
	world.advance(0.15)
	assert_lt(wolf.hp, hp, "landed")
	assert_eq(hero.cast_water[&"W02"], 24, "its power: 24 points")


func test_the_second_press_decides_how_much_water_comes_back() -> void:
	assert_almost_eq(WaterBending.whip_share(0.0), 0.5, 0.001, "at once: half")
	assert_almost_eq(WaterBending.whip_share(0.25), 0.75, 0.001)
	assert_almost_eq(WaterBending.whip_share(0.5), 1.0, 0.001, "at 0.5 s: all")
	assert_almost_eq(WaterBending.whip_share(1.0), 0.5, 0.001)
	assert_almost_eq(WaterBending.whip_share(1.5), 0.0, 0.001, "at 1.5 s: none")
	_go(_tile_from_water(8.0, 40.0))
	_stance(1)
	_fill_rope()
	var wolf := sim.add_enemy(ContentDB.enemies[&"wolf"], hero.tile() + Vector2i(2, 0))
	_cast(wolf)
	world.advance(1.0 - 0.05) # pressed 1 s after the throw: half comes back
	world.submit(hero.id, {"type": "water_return"})
	var events := world.step()
	var back: Array = events.filter(func(e): return e.type == "water_return")
	assert_eq(back.size(), 1)
	assert_eq(hero.stance_water, 12, "half of 24")
	assert_true(hero.water_out.is_empty())
	# No press: nothing comes back after 1.5 s, and the rope grows again from the pouch.
	world.advance(3.0)
	var pouch := hero.water
	var stance := hero.stance_water
	_cast(wolf)
	assert_eq(hero.stance_water, 0)
	world.advance(1.6)
	assert_true(hero.water_out.is_empty(), "the window closed")
	assert_lt(hero.stance_water, stance, "the water left on the ground is lost")
	assert_lt(hero.water, pouch, "the rope grows back from the pouch")


func test_stance_1_refills_a_point_every_8_5_frames_from_the_pouch() -> void:
	_go(_tile_from_water(8.0, 40.0))
	_stance(1)
	hero.stance_water = 20
	hero.stance_busy_at = sim.now
	var pouch := hero.water
	world.advance(8.5 / 60.0 * 2 + 0.01)
	assert_eq(hero.stance_water, 22)
	assert_eq(hero.water, pouch - 2)
	hero.water = 0
	world.advance(2.0)
	assert_eq(hero.stance_water, 22, "an empty pouch: the rope stops growing")


func test_power_follows_the_stance_water() -> void:
	var whip: AbilityDef = ContentDB.abilities[&"W02"]
	hero.stance_tree = "Water"
	hero.stance = 1
	hero.stance_water = 24
	assert_almost_eq(WaterBending.power(hero, whip), 1.0, 0.0001)
	hero.stance_water = 12
	assert_almost_eq(WaterBending.power(hero, whip), 0.6, 0.0001, "0.2 + 0.8 × 12/24")
	hero.stance_water = 0
	assert_almost_eq(WaterBending.power(hero, whip), 0.2, 0.0001)
	hero.cast_water[whip.id] = 24
	assert_almost_eq(WaterBending.power(hero, whip), 1.0, 0.0001, "the water it was cast with")
	hero.cast_water.clear()
	hero.stance_tree = ""
	hero.stance = 0
	assert_almost_eq(WaterBending.power(hero, whip), 1.0, 0.0001, "a tooltip out of the stance: full")


func test_the_stance_drops_after_10_s_idle_out_of_combat() -> void:
	_go(_tile_from_water(8.0, 40.0))
	_stance(1)
	world.advance(9.5)
	assert_eq(hero.stance, 1)
	var events := []
	for i in 20:
		events.append_array(world.step())
	assert_eq(hero.stance, 0, "dropped")
	assert_true(events.any(func(e): return e.type == "stance" and e.why == "idle"))
	assert_eq(hero.water, 200, "all its water back in the pouch")


func test_stance_2_needs_27_and_takes_33() -> void:
	_go(_tile_from_water(8.0, 40.0))
	hero.water = 26
	world.submit(hero.id, {"type": "stance", "tree": "Water", "stance": 2})
	var events := world.step()
	assert_true(events.any(func(e): return e.type == "rejected" and e.reason == "not_enough_water"))
	assert_eq(hero.stance, 0)
	hero.water = 30
	_stance(2)
	assert_eq(hero.stance, 2)
	assert_eq(hero.stance_water, 30, "27–32: all of it")
	_stance(0)
	hero.water = 200
	_stance(1)
	_fill_rope()
	_stance(2)
	assert_eq(hero.stance_water, 33, "stance water first, then the pouch, up to 33")
	assert_eq(hero.water, 167)
	_stance(1)
	assert_eq(hero.stance_water, 24, "back to stance 1: the rest goes to the pouch")
	assert_eq(hero.water, 176)


func test_e_at_water_fills_the_pouch_over_10_s_and_moving_stops_it() -> void:
	hero.water = 3
	_go(_tile_from_water(8.0, 40.0))
	world.submit(hero.id, {"type": "fill_water"})
	assert_eq(world.step().filter(func(e): return e.type == "rejected").map(func(e): return e.reason), ["too_far"])
	_go(_tile_from_water(1.0, 1.5))
	hero.water = 100
	world.submit(hero.id, {"type": "fill_water"})
	world.step()
	world.advance(2.5)
	assert_almost_eq(hero.water, 150, 3, "20 points a second")
	var events := []
	for i in 60:
		events.append_array(world.step())
	assert_eq(hero.water, 200, "half a pouch: 5 s")
	assert_true(events.any(func(e): return e.type == "pouch_filled"))
	hero.water = 0
	world.submit(hero.id, {"type": "fill_water"})
	world.step()
	world.advance(1.0)
	hero.move.place(hero.tile() + Vector2i(0, 0))
	hero.move.pos += Vector2(0.3, 0)
	events = world.step()
	assert_true(events.any(func(e): return e.type == "pouch_filling" and not e.on and e.why == "moved"))
	var left := hero.water
	world.advance(1.0)
	assert_eq(hero.water, left, "stopped")


func test_saved_with_the_character_and_older_water_heroes_get_a_pouch() -> void:
	_go(_tile_from_water(8.0, 40.0))
	_stance(1)
	_fill_rope()
	hero.water = 50
	var data := CharacterData.capture(hero)
	assert_eq(int(data.water), 74, "the orbit's water counts as the pouch's")
	var back := CharacterData.restore(9, data, ContentDB)
	assert_eq(back.water, 74)
	data.erase("water")
	for i in data.bag.size():
		if data.bag[i] is Array and str(data.bag[i][0]) == "water_pouch":
			data.bag[i] = null
	var old := CharacterData.restore(10, data, ContentDB)
	assert_true(old.has_water_pouch(), "a Water hero from before gets one")
	assert_eq(old.water, 200)


func test_sold_by_odo_and_tamsin() -> void:
	assert_true(ContentDB.npcs[&"apothecary_odo"].sells_ids.has(&"water_pouch"))
	assert_true(ContentDB.npcs[&"trader_tamsin"].sells_ids.has(&"water_pouch"))
