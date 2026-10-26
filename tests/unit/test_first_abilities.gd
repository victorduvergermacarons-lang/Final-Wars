extends GutTest
## The first ~30 tree abilities (Milestone 3 §5): their behavior files load
## through ContentDB, every one can be cast and does what its sheet row says.

const ContentDBScript := preload("res://autoload/content_db.gd")
const FIRST := ["F01", "F02", "F03", "F04", "F05", "F06", "F07", "F08", "F09",
		"W01", "W02", "W03", "W04", "W05", "W06", "W07", "W08", "W09",
		"A01", "A02", "A03", "A05", "E01", "E03", "E04", "E05",
		"S01", "S04", "B01", "B02", "H01", "H02"]

var db
var world: WorldSim
var hero: Hero
var foe: Enemy


func before_all() -> void:
	db = ContentDBScript.new()


func after_all() -> void:
	db.free()


func before_each() -> void:
	var rules: CombatRules = db.rules.duplicate()
	rules.out_of_combat_hp_regen_percent = 0.0
	rules.out_of_combat_mana_regen_percent = 0.0
	rules.in_combat_mana_regen_percent = 0.0
	var zone := ZoneDef.new()
	zone.id = &"arena"
	var heights: PackedStringArray = []
	var walk: PackedStringArray = []
	for y in 15:
		heights.append("0".repeat(15))
		walk.append(".".repeat(15))
	zone.height_rows = heights
	zone.walk_rows = walk
	zone.graveyards = [Vector2i(0, 0)]
	zone.hero_spawns = [Vector2i(5, 5)]
	world = WorldSim.new(zone, rules, 3)
	var def := EnemyDef.new()
	def.id = &"dummy"
	def.stats = StatBlock.make({Stat.Id.HP: 2000})
	def.aggro_radius = 0
	foe = world.add_enemy(def, Vector2i(6, 5))
	var hd := HeroDef.new()
	hd.base_stats = StatBlock.make({Stat.Id.HP: 500, Stat.Id.MANA: 500, Stat.Id.MAG_ATK: 10, Stat.Id.PHYS_ATK: 10,
			Stat.Id.JUMP: 2})
	hero = world.add_hero(hd)
	world.step()
	foe.face(Vector2i(-1, 0))


func _a(id: String) -> AbilityDef:
	return db.abilities[StringName(id)]


func _lost(actor: Actor) -> float:
	return actor.current_stats(world.now).hp - actor.hp


func test_the_first_abilities_are_implemented_and_the_rest_are_not() -> void:
	for id in FIRST:
		assert_true(_a(id).implemented, id)
	var others: Array = db.tree.ids().filter(func(id): return not String(id) in FIRST)
	assert_eq(others.size(), 145 - FIRST.size())
	for id in others:
		assert_false(db.abilities[StringName(id)].implemented, String(id))


func test_behavior_keeps_sheet_numbers() -> void:
	var fireball := _a("F07")
	assert_eq(fireball.display_name, "Fireball")
	assert_eq(fireball.cooldown_seconds, 8.0, "cooldown from the sheet")
	assert_eq(fireball.tree, "Fire")
	assert_eq(fireball.tier, 2)


func test_every_first_ability_can_be_cast() -> void:
	for id in FIRST:
		before_each()
		var a := _a(id)
		var target: Actor = foe
		var aim: Variant = null
		if a.target == AbilityDef.TargetType.ALLY or a.target == AbilityDef.TargetType.SELF:
			target = hero
		if a.targeting == AbilityDef.TargetingMode.GROUND:
			target = null
			aim = Vector2(7, 5) if id != "F05" else Vector2(5, 8)
		elif a.targeting == AbilityDef.TargetingMode.SKILLSHOT:
			aim = Vector2(foe.tile())
		var result := world.cast(hero, a, target, aim)
		assert_eq(result, AbilityResolver.Result.OK, "%s casts" % id)


func test_fire_punch_and_slash_hit_an_adjacent_enemy() -> void:
	world.cast(hero, _a("F01"), foe)
	var after_punch := _lost(foe)
	assert_gt(after_punch, 0.0)
	world.advance(1.1) # GCD
	world.cast(hero, _a("S01"), foe) # a timing bar: it hits on the press
	assert_eq(_lost(foe), after_punch, "not yet")
	world.advance(0.8)
	world.submit(hero.id, {"type": "timing_press", "at": 0.8})
	world.step()
	assert_gt(_lost(foe), after_punch)


func test_fire_kick_burns_over_time() -> void:
	world.cast(hero, _a("F02"), foe)
	var up_front := _lost(foe)
	world.advance(3.1)
	assert_gt(_lost(foe), up_front, "the burn ticks")


func test_kindle_boosts_the_next_three_fire_abilities() -> void:
	world.cast(hero, _a("F01"), foe)
	var plain := _lost(foe)
	world.cast(hero, _a("F04"), hero)
	assert_true(hero.buffs.has(&"kindled", world.now), "Kindle doesn't use its own charge")
	for i in 3:
		world.advance(2.1)
		var before := _lost(foe)
		world.cast(hero, _a("F01"), foe)
		assert_gt(_lost(foe) - before, plain, "boosted hit %d" % (i + 1))
	assert_false(hero.buffs.has(&"kindled", world.now), "three charges used")


func test_sun_warriors_breath_restores_mana_over_10s() -> void:
	assert_eq(_a("F04").display_name, "Sun Warrior's Breath")
	assert_eq(ContentDB_items_name("sun_warriors_breath_scroll"), "Sun Warrior's Breath Scroll")
	world.rules.in_combat_mana_regen_percent = 0.0
	world.rules.out_of_combat_mana_regen_percent = 0.0
	hero.mana = 100.0
	world.cast(hero, _a("F04"), hero)
	var after_cost := hero.mana
	world.advance(10.5)
	assert_almost_eq(hero.mana - after_cost, 50.0, 1.5, "10% of 500 max Mana")
	world.advance(5.0)
	assert_almost_eq(hero.mana - after_cost, 50.0, 1.5, "and no more after 10 s")


func ContentDB_items_name(id: String) -> String:
	return db.items[StringName(id)].display_name


func test_flame_dash_burns_the_tiles_behind() -> void:
	world.cast(hero, _a("F05"), null, Vector2(5, 8))
	assert_eq(hero.tile(), Vector2i(5, 8))
	assert_eq(world.ground_zones().size(), 1)
	assert_true(Vector2i(5, 6) in world.ground_zones()[0].tiles)
	assert_gt(hero.cooldowns.ability_remaining(&"F05", world.now), 0.0)


func test_flame_dash_gets_a_charge_per_300_fire_mastery() -> void:
	hero.growth.set_stat(Stat.Id.FIRE_MASTERY, 300)
	hero.refresh_stats()
	assert_eq(world.cast(hero, _a("F05"), null, Vector2(5, 7)), AbilityResolver.Result.OK)
	world.advance(1.1)
	assert_eq(world.cast(hero, _a("F05"), null, Vector2(5, 9)), AbilityResolver.Result.OK, "second charge")


func test_fire_whip_hits_every_enemy_in_the_line() -> void:
	var second := world.add_enemy(foe.def, Vector2i(8, 5))
	world.cast(hero, _a("F06"), null, Vector2(8, 5))
	assert_gt(_lost(foe), 0.0)
	assert_gt(_lost(second), 0.0)


func test_fireball_is_telegraphed_then_hits_the_area() -> void:
	world.cast(hero, _a("F07"), null, Vector2(7, 5))
	assert_eq(_lost(foe), 0.0, "not yet")
	assert_eq(world.pending_hits().size(), 1)
	world.advance(0.45)
	assert_gt(_lost(foe), 0.0)


func test_burning_ground_burns_while_standing_in_it() -> void:
	world.cast(hero, _a("F08"), null, Vector2(7, 5))
	world.advance(6.1)
	var burned := _lost(foe)
	assert_gt(burned, 0.0)
	world.advance(2.0)
	assert_eq(_lost(foe), burned, "gone after 6 s")


func test_blazing_combo_hits_three_times_and_knocks_back() -> void:
	world.cast(hero, _a("F09"), foe)
	assert_eq(foe.tile(), Vector2i(7, 5))
	assert_gt(_lost(foe), 0.0)


func test_rock_throw_lands_after_its_arc() -> void:
	foe.move.place(Vector2i(8, 5))
	world.cast(hero, _a("E01"), null, Vector2(8, 5))
	assert_eq(_lost(foe), 0.0)
	world.advance(0.35)
	assert_gt(_lost(foe), 0.0)


func test_raise_pillar_two_levels_at_500_mastery_but_not_three() -> void:
	world.cast(hero, _a("E03"), null, Vector2(6, 7))
	assert_eq(world.grid.height_at(Vector2i(6, 7)), 1)
	before_each()
	hero.growth.set_stat(Stat.Id.EARTH_MASTERY, 1200)
	hero.refresh_stats()
	world.cast(hero, _a("E03"), null, Vector2(6, 7))
	assert_eq(world.grid.height_at(Vector2i(6, 7)), 2)


func test_seismic_stomp_taunts_adjacent_enemies() -> void:
	var hd := HeroDef.new()
	hd.base_stats = StatBlock.make({Stat.Id.HP: 500, Stat.Id.MANA: 500})
	var tank := world.add_hero(hd)
	tank.move.place(Vector2i(7, 6))
	foe.threat.add(hero.id, 100.0)
	assert_eq(world.cast(tank, _a("E04"), null), AbilityResolver.Result.OK)
	assert_eq(foe.threat.top(), tank.id)


func test_earth_wall_can_be_climbed_with_enough_jump() -> void:
	world.cast(hero, _a("E05"), null, Vector2(5, 8))
	for x in [4, 5, 6]:
		assert_eq(world.grid.height_at(Vector2i(x, 8)), 2)
		assert_true(world.grid.is_walkable(Vector2i(x, 8)), "a wall is just high ground")
	assert_true(world.grid.can_step(Vector2i(5, 7), Vector2i(5, 8), 2), "Jump 2 climbs it")
	assert_false(world.grid.can_step(Vector2i(5, 7), Vector2i(5, 8), 1), "a Wolf (Jump 1) can't")


func test_earth_wall_lifts_an_enemy_and_hurts_it() -> void:
	foe.move.place(Vector2i(6, 8))
	var before := _lost(foe)
	world.cast(hero, _a("E05"), null, Vector2(5, 8))
	assert_eq(world.grid.height_at(foe.tile()), 2, "rides up with the wall")
	assert_between(_lost(foe) - before, 1.0, 15.0, "a small amount of damage")


func test_healing_touch_and_soothing_mist_heal() -> void:
	hero.hp = 100
	world.cast(hero, _a("W01"), hero)
	assert_gt(hero.hp, 100.0)
	var after := hero.hp
	world.advance(1.1)
	world.cast(hero, _a("W05"), hero)
	world.advance(12.1)
	assert_gt(hero.hp, after, "mist heals over time")


func test_flow_state_is_haste() -> void:
	world.cast(hero, _a("W03"), hero)
	assert_almost_eq(hero.buffs.cooldown_multiplier(world.now), 0.75, 0.001)
	assert_almost_eq(hero.buffs.step_multiplier(world.now), 0.75, 0.001)


func test_frost_shard_and_ice_spikes_slow() -> void:
	foe.move.place(Vector2i(9, 5))
	world.cast(hero, _a("W04"), null, Vector2(9, 5))
	world.advance(0.4)
	assert_gt(_lost(foe), 0.0)
	assert_gt(foe.buffs.step_multiplier(world.now), 1.0)
	before_each()
	world.cast(hero, _a("W09"), null, Vector2(7, 5))
	world.advance(0.45)
	assert_gt(foe.buffs.step_multiplier(world.now), 1.0)


func test_water_pulse_pushes_along_the_wave() -> void:
	world.cast(hero, _a("W06"), null, Vector2(8, 5))
	assert_eq(foe.tile(), Vector2i(7, 5))
	assert_gt(_lost(foe), 0.0)


func test_leeching_tide_heals_half_the_damage() -> void:
	hero.hp = 100
	world.cast(hero, _a("W07"), foe)
	assert_almost_eq(hero.hp - 100.0, roundf(_lost(foe) * 0.5), 1.0)


func test_tidal_blessing_adds_both_defenses() -> void:
	var before := hero.current_stats(world.now)
	world.cast(hero, _a("W08"), hero)
	var after := hero.current_stats(world.now)
	assert_eq(after.phys_def - before.phys_def, 20.0)
	assert_eq(after.mag_def - before.mag_def, 20.0)


func test_air_palm_and_air_blast_knock_back() -> void:
	world.cast(hero, _a("A01"), foe)
	assert_eq(foe.tile(), Vector2i(7, 5))
	world.grid.set_tile(Vector2i(9, 5), 0, false)
	world.advance(1.1)
	var before := _lost(foe)
	world.cast(hero, _a("A05"), foe)
	assert_eq(foe.tile(), Vector2i(8, 5), "stopped by the wall")
	assert_gt(_lost(foe) - before, 25.0, "damage plus impact")


func test_gust_interrupts_a_cast() -> void:
	foe.casting = {"kind": "cast", "ability": _a("F01"), "end": world.now + 5.0}
	world.cast(hero, _a("A02"), foe)
	assert_true(foe.casting.is_empty())


func test_air_step_gives_five_free_steps() -> void:
	world.cast(hero, _a("A03"), hero)
	assert_true(hero.buffs.has(&"air_step", world.now))


func test_lunge_steps_in_and_strikes() -> void:
	foe.move.place(Vector2i(8, 5))
	world.cast(hero, _a("S04"), foe)
	assert_eq(hero.tile(), Vector2i(7, 5))
	assert_gt(_lost(foe), 0.0)


func test_quick_shot_hits_at_range() -> void:
	foe.move.place(Vector2i(10, 5))
	world.cast(hero, _a("B01"), foe)
	assert_gt(_lost(foe), 0.0)


func test_aimed_shot_draws_for_a_second() -> void:
	foe.move.place(Vector2i(10, 5))
	world.cast(hero, _a("B02"), null, Vector2(10, 5))
	assert_false(hero.casting.is_empty(), "drawing")
	world.advance(1.5)
	assert_gt(_lost(foe), 0.0)


func test_smash_winds_up_and_can_be_stepped_away_from() -> void:
	world.cast(hero, _a("H01"), foe)
	assert_eq(_lost(foe), 0.0, "winding up")
	foe.move.place(Vector2i(6, 7))
	world.advance(0.4)
	assert_eq(_lost(foe), 0.0, "stepped away")


func test_ground_slam_hits_all_around() -> void:
	var second := world.add_enemy(foe.def, Vector2i(4, 4))
	world.cast(hero, _a("H02"), null)
	assert_gt(_lost(foe), 0.0)
	assert_gt(_lost(second), 0.0)
