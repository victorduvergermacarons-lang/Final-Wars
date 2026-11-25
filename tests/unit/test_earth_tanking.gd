extends GutTest
## The Earth (Stone Guard) tanking abilities: Rock Throw's ×3 threat, Seismic Stomp's
## 4 s taunt with light damage, Rumbling Taunt's 5 s taunt within 2 tiles, Metalbending
## (pull, Physical Defense down, a 3 s taunt only under Stone Skin or Earth Armor),
## and Stone Skin, Boulder Shield and Earth Armor.

const ContentDBScript := preload("res://autoload/content_db.gd")

var db
var world: WorldSim
var tank: Hero
var ally: Hero
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
	rules.timing_bars_enabled = false # these tests check effects
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
	foe = world.add_enemy(_foe_def(), Vector2i(6, 5))
	tank = _hero(Vector2i(5, 5))
	ally = _hero(Vector2i(5, 9))
	world.step()


func _foe_def() -> EnemyDef:
	var def := EnemyDef.new()
	def.id = &"dummy"
	def.stats = StatBlock.make({Stat.Id.HP: 5000})
	def.aggro_radius = 0
	return def


func _hero(at: Vector2i) -> Hero:
	var hd := HeroDef.new()
	hd.base_stats = StatBlock.make({Stat.Id.HP: 500, Stat.Id.MANA: 500, Stat.Id.PHYS_ATK: 10, Stat.Id.JUMP: 2})
	var h := world.add_hero(hd)
	h.move.place(at)
	return h


func _a(id: String) -> AbilityDef:
	return db.abilities[StringName(id)]


func _lost(actor: Actor) -> float:
	return actor.current_stats(world.now).hp - actor.hp


func _forced_for(enemy: Enemy, seconds: float) -> void:
	assert_true(enemy.threat.is_forced(world.now + seconds - 0.1), "forced for %.1f s" % seconds)
	assert_false(enemy.threat.is_forced(world.now + seconds + 0.1), "and no longer")


# --- Rock Throw -------------------------------------------------------------------

func test_rock_throw_makes_three_times_its_damage_in_threat() -> void:
	foe.move.place(Vector2i(8, 5))
	world.cast(tank, _a("E01"), null, Vector2(8, 5))
	world.advance(0.4)
	var dealt := _lost(foe)
	assert_gt(dealt, 0.0)
	var def_mult := AbilityResolver.defense_threat_multiplier(world.ctx, tank)
	assert_almost_eq(foe.threat.get_threat(tank.id), dealt * 3.0 * def_mult, 0.01)


# --- Seismic Stomp ------------------------------------------------------------------

func test_seismic_stomp_taunts_for_4s_and_hits_lightly() -> void:
	var second := world.add_enemy(_foe_def(), Vector2i(4, 4)) # diagonal: one of the 8 tiles
	var far := world.add_enemy(_foe_def(), Vector2i(9, 5))
	for e in [foe, second, far]:
		e.threat.add(ally.id, 500.0)
	assert_eq(world.cast(tank, _a("E04"), null), AbilityResolver.Result.OK)
	for e in [foe, second]:
		assert_eq(e.threat.target(), tank.id)
		_forced_for(e, 4.0)
		assert_gt(_lost(e), 0.0, "light damage")
	assert_eq(far.threat.target(), ally.id, "3 tiles away: not taunted")
	assert_eq(_a("E04").cooldown_seconds, 10.0, "the stance sheet's cooldown")


func test_seismic_stomp_hits_lighter_than_rock_throw() -> void:
	var stomp: AbilityEffect = _a("E04").effects.filter(func(e): return e.kind == AbilityEffect.Kind.DAMAGE)[0]
	var rock: AbilityEffect = _a("E01").effects[0]
	var s := AbilityPower.amount(tank, _a("E04"), stomp, world.now, world.rules)
	var r := AbilityPower.amount(tank, _a("E01"), rock, world.now, world.rules)
	assert_gt(s, 0.0)
	assert_lt(s, r)
	assert_eq(stomp.damage_type, AbilityEffect.DamageType.PHYSICAL)


func test_the_tank_keeps_aggro_after_a_stomp() -> void:
	foe.threat.add(ally.id, 100.0)
	world.cast(tank, _a("E04"), null)
	foe.threat.add(ally.id, 5.0) # the damage dealer keeps hitting a little
	EnemyBrain.pick_target(world, foe)
	world.advance(5.0) # past the forced time
	assert_eq(EnemyBrain.pick_target(world, foe), tank.id, "the +10% lead and the stomp's damage hold it")


# --- Rumbling Taunt -----------------------------------------------------------------------

func test_rumbling_taunt_takes_everything_within_2_tiles_for_5s() -> void:
	var near := world.add_enemy(_foe_def(), Vector2i(7, 5)) # 2 tiles
	var far := world.add_enemy(_foe_def(), Vector2i(9, 5)) # 4 tiles
	for e in [foe, near, far]:
		e.threat.add(ally.id, 500.0)
	assert_eq(world.cast(tank, _a("E08"), null), AbilityResolver.Result.OK)
	for e in [foe, near]:
		assert_eq(e.threat.target(), tank.id)
		_forced_for(e, 5.0)
	assert_eq(far.threat.target(), ally.id)
	assert_eq(_a("E08").cooldown_seconds, 15.0, "the stance sheet's cooldown")
	assert_gt(tank.cooldowns.ability_remaining(&"E08", world.now), 14.0)


# --- Metalbending ---------------------------------------------------------------------------

func test_metalbending_bends_armor_and_slows_without_pulling() -> void:
	# Since the stance rework (2026-11-25): the sheet's debuff; the pull moved to Metal Cable.
	foe.move.place(Vector2i(9, 5)) # 4 tiles away
	foe.threat.add(ally.id, 500.0)
	var def_before := foe.current_stats(world.now).phys_def
	assert_eq(world.cast(tank, _a("E15"), foe), AbilityResolver.Result.OK)
	assert_eq(_a("E15").effects.filter(func(e): return e.kind == AbilityEffect.Kind.PULL).size(), 0, "no pull")
	assert_eq(foe.current_stats(world.now).phys_def, def_before - 20.0)
	assert_eq(foe.buffs.step_multiplier(world.now), 2.0, "half speed")
	assert_eq(foe.threat.target(), ally.id, "no taunt")
	assert_false(foe.threat.is_forced(world.now))


func test_metalbending_never_taunts_even_under_stone_skin() -> void:
	foe.move.place(Vector2i(9, 5))
	foe.threat.add(ally.id, 500.0)
	world.cast(tank, _a("E02"), null)
	world.advance(1.1) # the GCD
	assert_eq(world.cast(tank, _a("E15"), foe), AbilityResolver.Result.OK)
	assert_false(foe.threat.is_forced(world.now))


# --- Stone Skin, Boulder Shield, Earth Armor -----------------------------------------------------

func test_stone_skin_raises_defense_and_threat_while_up() -> void:
	var mult := AbilityResolver.defense_threat_multiplier(world.ctx, tank)
	var def := tank.current_stats(world.now).phys_def
	world.cast(tank, _a("E02"), null)
	assert_eq(tank.current_stats(world.now).phys_def, def + 20.0)
	assert_almost_eq(AbilityResolver.defense_threat_multiplier(world.ctx, tank),
			mult + 20.0 / world.rules.threat_def_divisor, 0.001)
	world.advance(11.0)
	assert_eq(tank.current_stats(world.now).phys_def, def, "gone after 10 s")


func test_earth_armor_is_a_big_defense_boost_that_slows() -> void:
	var def := tank.current_stats(world.now).phys_def
	world.cast(tank, _a("E14"), null)
	assert_eq(tank.current_stats(world.now).phys_def, def + 50.0)
	assert_eq(tank.buffs.step_multiplier(world.now), 2.0, "steps 50% slower")


func test_boulder_shield_absorbs_damage() -> void:
	world.cast(tank, _a("E07"), null)
	assert_true(tank.buffs.has(&"boulder_shield", world.now))
	var events: Array[Dictionary] = []
	AbilityResolver.deal_damage(world.ctx, foe, tank, &"test", 10.0, false, events)
	assert_eq(_lost(tank), 0.0, "absorbed")


func test_other_earth_abilities_get_no_threat_bonus() -> void:
	for id in ["E03", "E05"]:
		for e in _a(id).effects:
			assert_eq(e.threat_multiplier, 1.0, id)
