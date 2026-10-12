extends GutTest
## Effect building blocks, part 1: damage/heal over time, shields, stat buffs,
## stun/silence/sleep, haste, charged damage bonus (Kindle), free steps (Air Step),
## cast times, wind-ups, channels, interrupts and charges.

var rules: CombatRules
var world: WorldSim
var hero: Hero
var foe: Enemy


func before_each() -> void:
	rules = CombatRules.new()
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
	var def := EnemyDef.new()
	def.id = &"dummy"
	def.stats = StatBlock.make({Stat.Id.HP: 1000})
	def.aggro_radius = 0
	var spawn := EnemySpawn.new()
	spawn.enemy = def
	spawn.tile = Vector2i(6, 5)
	zone.enemy_spawns = [spawn]
	world = WorldSim.new(zone, rules, 3)
	foe = world.enemies()[0]
	var hd := HeroDef.new()
	hd.base_stats = StatBlock.make({Stat.Id.HP: 500, Stat.Id.MANA: 500})
	hero = world.add_hero(hd)
	world.step()


func _buff(id: StringName, seconds: float, props: Dictionary = {}) -> BuffDef:
	var b := BuffDef.new()
	b.id = id
	b.duration_seconds = seconds
	for k in props:
		b.set(k, props[k])
	return b


func _ability(kind: AbilityEffect.Kind, base: float, props: Dictionary = {}, buff: BuffDef = null) -> AbilityDef:
	var a := AbilityDef.new()
	a.id = StringName("t_%d" % randi())
	a.targeting = AbilityDef.TargetingMode.TARGETED
	a.max_range = 5
	a.on_gcd = false
	var e := AbilityEffect.new()
	e.kind = kind
	e.base_amount = base
	e.can_crit = false
	e.buff = buff
	a.effects = [e] as Array[AbilityEffect]
	if kind in [AbilityEffect.Kind.HEAL, AbilityEffect.Kind.SHIELD, AbilityEffect.Kind.HEAL_OVER_TIME,
			AbilityEffect.Kind.BUFF]:
		a.target = AbilityDef.TargetType.ALLY
	for k in props:
		a.set(k, props[k])
	return a


func _lost(actor: Actor) -> float:
	return actor.stats.hp - actor.hp


func test_damage_over_time_ticks_and_adds_threat() -> void:
	var dot := _ability(AbilityEffect.Kind.DAMAGE_OVER_TIME, 40, {}, _buff(&"burn", 4.0, {"is_debuff": true}))
	world.cast(hero, dot, foe)
	assert_eq(_lost(foe), 0.0, "nothing up front")
	world.advance(4.1)
	assert_almost_eq(_lost(foe), 40.0, 1.0, "40 over 4 ticks")
	assert_true(foe.threat.has(hero.id))


func test_shield_absorbs_then_breaks() -> void:
	var shield := _ability(AbilityEffect.Kind.SHIELD, 30, {}, _buff(&"ward", 10.0))
	world.cast(hero, shield, hero)
	assert_eq(hero.buffs.shield_total(), 30.0)
	var events: Array[Dictionary] = []
	AbilityResolver.deal_damage(world.ctx, foe, hero, &"hit", 20.0, false, events)
	assert_eq(_lost(hero), 0.0, "fully absorbed")
	assert_eq(events[0].absorbed, 20.0)
	AbilityResolver.deal_damage(world.ctx, foe, hero, &"hit", 20.0, false, events)
	assert_eq(_lost(hero), 10.0, "the last 10 shield, then 10 through")
	assert_false(hero.buffs.has(&"ward", world.now), "a used-up shield ends")


func test_stun_stops_steps_and_abilities() -> void:
	var stun := _ability(AbilityEffect.Kind.BUFF, 0, {}, _buff(&"stun", 2.0, {"stuns": true, "is_debuff": true}))
	world.cast(hero, stun, hero)
	assert_eq(world.try_step(hero, Vector2i(5, 4)), "stunned")
	var hit := _ability(AbilityEffect.Kind.DAMAGE, 10)
	assert_eq(world.cast(hero, hit, foe), AbilityResolver.Result.STUNNED)


func test_silence_blocks_spells_not_weapon_arts() -> void:
	world.cast(hero, _ability(AbilityEffect.Kind.BUFF, 0, {}, _buff(&"mute", 3.0, {"silences": true})), hero)
	var spell := _ability(AbilityEffect.Kind.DAMAGE, 10, {"tree": "Fire"})
	var art := _ability(AbilityEffect.Kind.DAMAGE, 10, {"tree": "Sword"})
	assert_eq(world.cast(hero, spell, foe), AbilityResolver.Result.SILENCED)
	assert_eq(world.cast(hero, art, foe), AbilityResolver.Result.OK)


func test_sleep_breaks_on_damage() -> void:
	var sleep := _ability(AbilityEffect.Kind.BUFF, 0, {"target": AbilityDef.TargetType.ENEMY},
			_buff(&"sleep", 10.0, {"sleeps": true}))
	world.cast(hero, sleep, foe)
	assert_true(foe.buffs.is_stunned(world.now))
	world.cast(hero, _ability(AbilityEffect.Kind.DAMAGE, 5), foe)
	assert_false(foe.buffs.is_stunned(world.now), "woken up")


func test_haste_shortens_cooldowns() -> void:
	var haste := _buff(&"haste", 30.0, {"cooldown_multiplier": 0.75, "step_cooldown_multiplier": 0.75})
	world.cast(hero, _ability(AbilityEffect.Kind.BUFF, 0, {}, haste), hero)
	var slow := _ability(AbilityEffect.Kind.DAMAGE, 1, {"cooldown_seconds": 8.0, "on_gcd": true})
	world.cast(hero, slow, foe)
	assert_almost_eq(hero.cooldowns.ability_remaining(slow.id, world.now), 6.0, 0.001)
	assert_almost_eq(hero.cooldowns.gcd_remaining(world.now), 0.75, 0.001)


func test_charged_damage_bonus_like_kindle() -> void:
	var kindle := _buff(&"kindle", 30.0, {"damage_dealt_multiplier": 2.0, "affects_tree": "Fire", "charges": 3})
	world.cast(hero, _ability(AbilityEffect.Kind.BUFF, 0, {}, kindle), hero)
	var bolt := _ability(AbilityEffect.Kind.DAMAGE, 10, {"tree": "Fire"})
	var other := _ability(AbilityEffect.Kind.DAMAGE, 10, {"tree": "Water"})
	world.cast(hero, other, foe)
	assert_eq(_lost(foe), 10.0, "other trees don't use it")
	for i in 3:
		world.cast(hero, bolt, foe)
	assert_eq(_lost(foe), 70.0, "three doubled fire hits")
	assert_false(hero.buffs.has(&"kindle", world.now), "charges used up")
	world.cast(hero, bolt, foe)
	assert_eq(_lost(foe), 80.0)


func test_free_steps_like_air_step() -> void:
	hero.combat_until = 1.0e9
	var step := _buff(&"air_step", 30.0, {"free_steps": true, "charges": 2})
	world.cast(hero, _ability(AbilityEffect.Kind.BUFF, 0, {}, step), hero)
	assert_eq(world.try_step(hero, Vector2i(5, 4)), "")
	world.advance(0.25)
	assert_eq(world.try_step(hero, Vector2i(5, 3)), "", "no step cooldown")
	world.advance(0.25)
	assert_eq(world.try_step(hero, Vector2i(5, 2)), "")
	world.advance(0.25)
	assert_eq(world.try_step(hero, Vector2i(5, 1)), "not_ready", "charges spent: normal step cooldown")


func test_cast_time_resolves_later_and_moving_cancels_it() -> void:
	var slow := _ability(AbilityEffect.Kind.DAMAGE, 50, {"cast_seconds": 1.0, "mana_cost": 20.0, "cooldown_seconds": 5.0})
	assert_eq(world.cast(hero, slow, foe), AbilityResolver.Result.OK)
	assert_eq(_lost(foe), 0.0)
	assert_eq(world.cast(hero, _ability(AbilityEffect.Kind.DAMAGE, 1), foe), AbilityResolver.Result.BUSY)
	world.advance(1.05)
	assert_eq(_lost(foe), 50.0)
	assert_eq(hero.mana, 480.0)
	hero.cooldowns = Cooldowns.new()
	world.cast(hero, slow, foe)
	world.advance(0.5)
	world.try_step(hero, Vector2i(5, 4))
	world.advance(1.0)
	assert_eq(_lost(foe), 50.0, "cancelled by moving")
	assert_eq(hero.mana, 480.0, "no mana spent")
	assert_true(hero.cooldowns.can_use(slow, world.now), "no cooldown spent")


func test_cast_fails_if_the_target_leaves_range() -> void:
	var slow := _ability(AbilityEffect.Kind.DAMAGE, 50, {"cast_seconds": 1.0, "max_range": 2})
	world.cast(hero, slow, foe)
	foe.move.place(Vector2i(10, 5))
	world.advance(1.1)
	assert_eq(_lost(foe), 0.0)
	assert_true(hero.casting.is_empty())


func test_windup_roots_the_caster_but_the_target_can_step_away() -> void:
	var smash := _ability(AbilityEffect.Kind.DAMAGE, 50, {"windup_seconds": 0.3, "max_range": 1})
	world.cast(hero, smash, foe)
	assert_eq(world.try_step(hero, Vector2i(5, 4)), "busy")
	foe.move.place(Vector2i(7, 5))
	world.advance(0.35)
	assert_eq(_lost(foe), 0.0, "stepped away from the wind-up")
	world.cast(hero, smash, foe) # out of range now
	foe.move.place(Vector2i(6, 5))
	foe.face(Vector2i.LEFT) # facing the hero: no flank bonus
	hero.cooldowns = Cooldowns.new()
	world.cast(hero, smash, foe)
	world.advance(0.35)
	assert_eq(_lost(foe), 50.0)


func test_channel_ticks_and_ends_when_moving() -> void:
	var beam := _ability(AbilityEffect.Kind.DAMAGE, 10, {"channel_seconds": 3.0, "channel_tick_seconds": 1.0})
	world.cast(hero, beam, foe)
	world.advance(3.1)
	assert_eq(_lost(foe), 30.0, "3 ticks")
	foe.hp = foe.stats.hp
	world.cast(hero, beam, foe)
	world.advance(1.05)
	world.try_step(hero, Vector2i(5, 4))
	world.advance(3.0)
	assert_eq(_lost(foe), 10.0, "moving ended it")


func test_interrupt_cancels_a_cast() -> void:
	var slow := _ability(AbilityEffect.Kind.DAMAGE, 50, {"cast_seconds": 2.0, "target": AbilityDef.TargetType.ENEMY})
	world.cast(foe, slow, hero)
	assert_false(foe.casting.is_empty())
	var gust := _ability(AbilityEffect.Kind.INTERRUPT, 0)
	world.cast(hero, gust, foe)
	assert_true(foe.casting.is_empty())
	world.advance(2.5)
	assert_eq(_lost(hero), 0.0)


func test_charges_recharge_one_at_a_time() -> void:
	var dash := _ability(AbilityEffect.Kind.DAMAGE, 1, {"charges_base": 2, "cooldown_seconds": 4.0})
	assert_eq(world.cast(hero, dash, foe), AbilityResolver.Result.OK)
	assert_eq(world.cast(hero, dash, foe), AbilityResolver.Result.OK, "second charge")
	assert_eq(world.cast(hero, dash, foe), AbilityResolver.Result.ON_COOLDOWN)
	world.advance(4.05)
	assert_eq(world.cast(hero, dash, foe), AbilityResolver.Result.OK, "one charge back after 4 s")
	assert_eq(world.cast(hero, dash, foe), AbilityResolver.Result.ON_COOLDOWN, "the other recharges next")


func test_mastery_adds_charges() -> void:
	var dash := _ability(AbilityEffect.Kind.DAMAGE, 1, {"charges_base": 1, "mastery_per_charge": 300.0,
			"cooldown_seconds": 8.0, "tree": "Fire"})
	Mastery.add_permanent(hero, "Fire", 300)
	assert_eq(AbilityResolver.max_charges(hero, dash, world.now), 2)
	world.cast(hero, dash, foe)
	assert_eq(world.cast(hero, dash, foe), AbilityResolver.Result.OK)
