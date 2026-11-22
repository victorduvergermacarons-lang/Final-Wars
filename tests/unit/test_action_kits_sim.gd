extends GutTest
## The host side of the Hades-style kits (2026-11-22): instant hero combat, attacks
## without a target, Stone Skin's stacks, Air's wind charges, Raise Pillar's height
## from the hold and Stone Fist sliding the pillar.

var world: World
var sim: WorldSim
var hero: Hero
var wolf: Enemy


func before_each() -> void:
	ContentDB.rules.action_combat = true
	world = World.new(ContentDB.zones.values(), ContentDB.rules, 5, &"town", ContentDB.quests)
	hero = world.add_saved_hero(CharacterData.new_character("Kit", ContentDB.heroes[&"adventurer"]), ContentDB)
	for id in [&"F01", &"W02", &"E02", &"E03", &"E21", &"A01", &"A03", &"A05", &"W24", &"W25"]:
		hero.mastered[id] = ContentDB.abilities[id]
	sim = world.zone_of(hero.id)
	hero.move.place(Vector2i(6, 7))
	hero.face(Vector2i.RIGHT)
	hero.mana = hero.current_stats(0.0).mana
	world.step()


func after_each() -> void:
	ContentDB.rules.action_combat = false


func _cast(id: StringName, aim: Vector2, charge := 0.0) -> Array:
	var intent := {"type": "cast", "ability": id, "target": -1, "aim": aim}
	if charge > 0.0:
		intent.charge = charge
	world.submit(hero.id, intent)
	return world.step()


func _wolf_at(offset: Vector2i) -> Enemy:
	wolf = sim.add_enemy(ContentDB.enemies[&"wolf"], hero.tile() + offset)
	wolf.threat.add(hero.id, 1.0)
	return wolf


static func _of(events: Array, type: String) -> Array:
	return events.filter(func(e): return e.type == type)


func test_hero_attacks_go_off_at_once_with_a_short_gcd() -> void:
	_wolf_at(Vector2i(1, 0))
	var hp := wolf.hp
	_cast(&"F01", wolf.move.pos)
	assert_true(hero.casting.is_empty(), "no bar, cast time or wind-up")
	assert_lt(wolf.hp, hp, "the punch landed without a target")
	assert_almost_eq(hero.cooldowns.gcd_remaining(world.now), ContentDB.rules.action_gcd_seconds - 0.05, 0.06)


func test_water_whip_flies_without_a_target() -> void:
	_wolf_at(Vector2i(3, 0))
	var hp := wolf.hp
	_cast(&"W02", wolf.move.pos)
	world.advance(0.5)
	assert_lt(wolf.hp, hp, "a projectile now")


func test_stone_skin_stacks_a_third_each_press() -> void:
	var base := hero.current_stats(world.now).phys_def
	_cast(&"E02", hero.move.pos)
	var one := hero.current_stats(world.now).phys_def - base
	world.advance(0.4)
	_cast(&"E02", hero.move.pos)
	world.advance(0.4)
	_cast(&"E02", hero.move.pos)
	world.advance(0.4)
	_cast(&"E02", hero.move.pos)
	var full := hero.current_stats(world.now).phys_def - base
	assert_almost_eq(one, 20.0 / 3.0, 0.5, "one press: a third")
	assert_almost_eq(full, 20.0, 0.5, "three presses (a fourth adds nothing): the whole +20")
	assert_eq(hero.buffs.stacks(&"stone_skin", world.now), 3)


func test_air_step_dashes_and_fills_a_wind_charge() -> void:
	var from := hero.move.pos
	_cast(&"A03", from + Vector2(5, 0))
	world.advance(0.6)
	assert_gt(hero.move.pos.distance_to(from), 3.0, "a long dash")
	assert_eq(hero.element_points, 1)
	for i in 4:
		world.advance(2.6)
		_cast(&"A03", hero.move.pos + Vector2(-5, 0) if i % 2 == 0 else hero.move.pos + Vector2(5, 0))
	assert_eq(hero.element_points, ContentDB.rules.element_points_max, "up to 3")


func test_air_palm_spends_the_charges_for_more_damage_and_a_stun() -> void:
	_wolf_at(Vector2i(1, 0))
	var hp := wolf.hp
	_cast(&"A01", wolf.move.pos)
	var plain := hp - wolf.hp
	world.advance(4.5)
	wolf.hp = hp
	wolf.move.place(hero.tile() + Vector2i(1, 0))
	hero.element_points = 3
	_cast(&"A01", wolf.move.pos)
	assert_eq(hero.element_points, 0, "all spent")
	assert_gt(hp - wolf.hp, plain * 1.5, "+30% per charge")
	assert_true(wolf.buffs.has(&"wind_stun", world.now), "a full spend stuns")


func test_raise_pillar_grows_with_the_hold() -> void:
	var t := hero.tile() + Vector2i(1, 0)
	var ground := sim.grid.height_at(t)
	_cast(&"E03", Vector2(t), 1.3)
	assert_eq(sim.grid.height_at(t), ground + 3, "1 level + 1 per 0.6 s held")


func test_stone_fist_slides_your_pillar_five_tiles() -> void:
	var t := hero.tile() + Vector2i(1, 0)
	var ground := sim.grid.height_at(t)
	_cast(&"E03", Vector2(t))
	assert_eq(sim.grid.height_at(t), ground + 1)
	world.advance(0.3)
	_cast(&"E21", Vector2(t) + Vector2(1, 0))
	world.advance(1.0)
	assert_eq(sim.grid.height_at(t), ground, "it left its tile")
	var moved := false
	for i in range(2, 8):
		var s := hero.tile() + Vector2i(i, 0)
		if sim.grid.in_bounds(s) and sim.changed_terrain().any(func(c): return c[0] == s):
			moved = true
	assert_true(moved, "it stands further along now")


func test_ice_mode_abilities_work() -> void:
	_wolf_at(Vector2i(1, 0))
	var hp := wolf.hp
	_cast(&"W25", hero.move.pos)
	assert_lt(wolf.hp, hp, "Frost Ring hits around you")
	assert_true(wolf.buffs.has(&"frost_ring_chill", world.now), "and chills")
	var from := hero.move.pos
	world.advance(0.5)
	_cast(&"W24", from + Vector2(0, 4))
	world.advance(0.6)
	assert_gt(hero.move.pos.distance_to(from), 2.0, "Ice Slide dashes")
