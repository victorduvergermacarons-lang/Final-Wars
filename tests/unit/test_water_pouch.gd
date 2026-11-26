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


func test_water_heroes_start_with_a_full_pouch() -> void:
	assert_true(hero.has_water_pouch())
	assert_eq(hero.water, 200)


func test_the_orbit_takes_24_away_from_water_and_gives_them_back() -> void:
	_go(_tile_from_water(8.0, 40.0))
	assert_false(hero.near_water)
	_stance(1)
	assert_true(hero.rope)
	assert_eq(hero.water, 176)
	_stance(0)
	assert_false(hero.rope)
	assert_eq(hero.water, 200, "back into the pouch")


func test_near_water_the_orbit_is_free() -> void:
	_go(_tile_from_water(1.0, 2.5))
	assert_true(hero.near_water)
	_stance(1)
	assert_true(hero.rope)
	assert_eq(hero.water, 200)


func test_no_water_no_orbit_no_whip() -> void:
	_go(_tile_from_water(8.0, 40.0))
	hero.water = 10
	_stance(1)
	assert_false(hero.rope, "not enough for the orbit")
	var wolf := sim.add_enemy(ContentDB.enemies[&"wolf"], hero.tile() + Vector2i(2, 0))
	assert_eq(AbilityResolver.has_water(hero, ContentDB.abilities[&"W02"]), false)
	var events := _cast(wolf)
	assert_true(events.any(func(e): return e.type == "rejected" and e.get("reason", "") == "no_water"),
			"refused: no water")


func _cast(target: Actor) -> Array:
	world.submit(hero.id, {"type": "cast", "ability": &"W02", "target": target.id})
	return world.step()


func test_each_whip_takes_4_and_lands_half_a_second_after_the_release() -> void:
	ContentDB.rules.timing_bars_enabled = true
	_go(_tile_from_water(8.0, 40.0))
	_stance(1)
	assert_eq(hero.water, 176)
	var wolf := sim.add_enemy(ContentDB.enemies[&"wolf"], hero.tile() + Vector2i(2, 0))
	var hp := wolf.hp
	_cast(wolf)
	var start := float(hero.casting.get("start", sim.now))
	world.advance(start + 0.45 - sim.now)
	world.submit(hero.id, {"type": "timing_press", "at": 0.45})
	world.step()
	world.advance(start + 2.3 - sim.now)
	world.submit(hero.id, {"type": "timing_release", "at": 2.3})
	world.step()
	var released := sim.now
	assert_almost_eq(ContentDB.abilities[&"W02"].release_delay_seconds, 0.5, 0.001, "the hit 0.5 s after the release")
	world.advance(released + 0.42 - sim.now)
	assert_eq(wolf.hp, hp, "not yet")
	world.advance(0.15)
	assert_lt(wolf.hp, hp, "landed")
	assert_eq(hero.water, 172, "4 from the pouch")


func test_near_water_the_whip_is_free() -> void:
	_go(_tile_from_water(1.0, 2.5))
	_stance(1)
	var wolf := sim.add_enemy(ContentDB.enemies[&"wolf"], hero.tile() + Vector2i(0, 0) + Vector2i(1, 1))
	_cast(wolf)
	world.advance(0.6)
	assert_eq(hero.water, 200)


func test_e_at_water_fills_the_pouch() -> void:
	hero.water = 3
	_go(_tile_from_water(8.0, 40.0))
	world.submit(hero.id, {"type": "fill_water"})
	assert_eq(world.step().filter(func(e): return e.type == "rejected").map(func(e): return e.reason), ["too_far"])
	_go(_tile_from_water(1.0, 1.5))
	world.submit(hero.id, {"type": "fill_water"})
	var events := world.step()
	assert_true(events.any(func(e): return e.type == "pouch_filled"))
	assert_eq(hero.water, 200)


func test_saved_with_the_character_and_older_water_heroes_get_a_pouch() -> void:
	_go(_tile_from_water(8.0, 40.0))
	_stance(1)
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
