extends GutTest

const R := AbilityResolver.Result

var rules: CombatRules
var ctx: CombatContext
var hero: Actor
var healer: Actor
var enemy: Actor


func _effect(kind: AbilityEffect.Kind, base: float, scaling: Array[AbilityScaling] = []) -> AbilityEffect:
	var e := AbilityEffect.new()
	e.kind = kind
	e.base_amount = base
	e.scaling = scaling
	return e


func _ability(id: StringName, target: AbilityDef.TargetType, effects: Array[AbilityEffect],
		max_range: int = 1, mana: float = 0.0, cooldown: float = 0.0) -> AbilityDef:
	var a := AbilityDef.new()
	a.id = id
	a.target = target
	a.effects = effects
	a.max_range = max_range
	a.mana_cost = mana
	a.cooldown_seconds = cooldown
	return a


func _strike() -> AbilityDef:
	# 10 + 1.0 × Physical Attack
	return _ability(&"strike", AbilityDef.TargetType.ENEMY,
			[_effect(AbilityEffect.Kind.DAMAGE, 10, [AbilityScaling.make(Stat.Id.PHYS_ATK, 1.0)])])


func _heal() -> AbilityDef:
	return _ability(&"heal", AbilityDef.TargetType.ALLY,
			[_effect(AbilityEffect.Kind.HEAL, 40)], 4, 10.0)


func _place(actor: Actor, tile: Vector2i) -> Actor:
	actor.move.place(tile)
	ctx.add_actor(actor)
	return actor


func before_each() -> void:
	rules = CombatRules.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	ctx = CombatContext.new(GridModel.new(10, 10), rules, rng)
	# Accuracy 100 → 100% hit; crit rate 0 → no crits, unless a test changes it.
	hero = _place(Actor.new(1, Actor.Team.HEROES, StatBlock.make({
		Stat.Id.HP: 100, Stat.Id.MANA: 50, Stat.Id.PHYS_ATK: 20, Stat.Id.ACCURACY: 100})), Vector2i(2, 2))
	healer = _place(Actor.new(2, Actor.Team.HEROES, StatBlock.make({
		Stat.Id.HP: 80, Stat.Id.MANA: 100})), Vector2i(2, 5))
	enemy = _place(Actor.new(10, Actor.Team.ENEMIES, StatBlock.make({
		Stat.Id.HP: 60, Stat.Id.PHYS_DEF: 100, Stat.Id.PHYS_ATK: 10, Stat.Id.ACCURACY: 100})), Vector2i(3, 2))


func test_strike_damage_threat_and_cooldowns() -> void:
	var out := AbilityResolver.cast(ctx, hero, _strike(), enemy)
	assert_eq(out.result, R.OK)
	# raw 30, half mitigated by 100 Physical Defense
	assert_eq(enemy.hp, 45.0)
	assert_eq(out.events[1].type, "damage")
	assert_eq(out.events[1].amount, 15.0)
	assert_eq(enemy.threat.get_threat(hero.id), 15.0)
	assert_gt(hero.cooldowns.gcd_remaining(ctx.now), 0.0, "GCD started")


func test_mana_is_spent_and_checked() -> void:
	var heal := _heal()
	healer.mana = 15
	assert_eq(AbilityResolver.cast(ctx, healer, heal, hero).result, R.OK)
	assert_eq(healer.mana, 5.0)
	ctx.now = 5.0
	assert_eq(AbilityResolver.cast(ctx, healer, heal, hero).result, R.NOT_ENOUGH_MANA)


func test_cooldown_and_gcd_are_enforced() -> void:
	var bash := _ability(&"bash", AbilityDef.TargetType.ENEMY,
			[_effect(AbilityEffect.Kind.DAMAGE, 1)], 1, 0.0, 6.0)
	assert_eq(AbilityResolver.cast(ctx, hero, bash, enemy).result, R.OK)
	ctx.now = 0.5
	assert_eq(AbilityResolver.cast(ctx, hero, _strike(), enemy).result, R.ON_COOLDOWN, "GCD")
	ctx.now = 2.0
	assert_eq(AbilityResolver.cast(ctx, hero, bash, enemy).result, R.ON_COOLDOWN, "own cooldown")
	assert_eq(AbilityResolver.cast(ctx, hero, _strike(), enemy).result, R.OK)


func test_range_and_line_of_sight() -> void:
	enemy.move.place(Vector2i(6, 2))
	assert_eq(AbilityResolver.validate(ctx, hero, _strike(), enemy), R.OUT_OF_RANGE)
	var bolt := _ability(&"bolt", AbilityDef.TargetType.ENEMY, [_effect(AbilityEffect.Kind.DAMAGE, 5)], 6)
	bolt.requires_line_of_sight = true
	assert_eq(AbilityResolver.validate(ctx, hero, bolt, enemy), R.OK)
	ctx.grid.set_tile(Vector2i(4, 2), 5, false)
	assert_eq(AbilityResolver.validate(ctx, hero, bolt, enemy), R.NO_LINE_OF_SIGHT)


func test_target_validation() -> void:
	assert_eq(AbilityResolver.validate(ctx, hero, _strike(), healer), R.INVALID_TARGET, "strike an ally")
	assert_eq(AbilityResolver.validate(ctx, healer, _heal(), enemy), R.INVALID_TARGET, "heal an enemy")
	assert_eq(AbilityResolver.validate(ctx, hero, _strike(), null), R.INVALID_TARGET)
	hero.die()
	assert_eq(AbilityResolver.validate(ctx, hero, _strike(), enemy), R.CASTER_DEAD)
	assert_eq(AbilityResolver.validate(ctx, healer, _heal(), hero), R.INVALID_TARGET, "heal the dead")


func test_failed_validation_changes_nothing() -> void:
	healer.mana = 0
	var out := AbilityResolver.cast(ctx, healer, _heal(), hero)
	assert_eq(out.result, R.NOT_ENOUGH_MANA)
	assert_eq(out.events.size(), 0)
	assert_eq(healer.cooldowns.gcd_remaining(ctx.now), 0.0)


func test_miss_still_costs_mana_and_cooldown() -> void:
	rules.base_hit_percent = 0
	rules.min_hit_percent = 0
	hero.stats.accuracy = 0
	var out := AbilityResolver.cast(ctx, hero, _strike(), enemy)
	assert_eq(out.events[1].type, "miss")
	assert_eq(enemy.hp, 60.0)
	assert_gt(hero.cooldowns.gcd_remaining(ctx.now), 0.0)


func test_crit_multiplies_before_mitigation() -> void:
	hero.stats.crit_rate = 100
	var out := AbilityResolver.cast(ctx, hero, _strike(), enemy)
	assert_true(out.events[1].crit)
	assert_eq(out.events[1].amount, 23.0, "30 × 1.5 = 45, halved = 22.5 → 23")


func test_killing_blow_emits_death() -> void:
	enemy.hp = 5
	var out := AbilityResolver.cast(ctx, hero, _strike(), enemy)
	assert_false(enemy.alive)
	assert_eq(enemy.hp, 0.0)
	assert_eq(out.events[1].amount, 5.0, "damage capped at remaining HP")
	assert_eq(out.events[2].type, "death")


func test_heal_is_capped_and_shares_threat_with_enemies_fighting_target() -> void:
	var enemy2 := _place(Actor.new(11, Actor.Team.ENEMIES, StatBlock.make({Stat.Id.HP: 50})), Vector2i(2, 1))
	enemy.threat.add(hero.id, 10)
	enemy2.threat.add(hero.id, 10)
	hero.hp = 70
	var out := AbilityResolver.cast(ctx, healer, _heal(), hero)
	assert_eq(hero.hp, 100.0, "40 heal capped at max")
	assert_eq(out.events[1].amount, 30.0)
	# 30 effective × 0.5 = 15 threat, split over two enemies
	assert_almost_eq(enemy.threat.get_threat(healer.id), 7.5, 0.0001)
	assert_almost_eq(enemy2.threat.get_threat(healer.id), 7.5, 0.0001)


func test_heal_out_of_combat_adds_no_threat() -> void:
	hero.hp = 50
	AbilityResolver.cast(ctx, healer, _heal(), hero)
	assert_false(enemy.threat.has(healer.id))


func test_taunt_takes_top_threat() -> void:
	enemy.threat.add(healer.id, 200)
	var taunt := _ability(&"taunt", AbilityDef.TargetType.ENEMY, [_effect(AbilityEffect.Kind.TAUNT, 0)], 3)
	AbilityResolver.cast(ctx, hero, taunt, enemy)
	assert_eq(enemy.threat.top(), hero.id)


func test_resurrect_restores_a_fraction_of_hp_and_mana() -> void:
	hero.die()
	hero.mana = 0
	var rez := _ability(&"resurrect", AbilityDef.TargetType.DEAD_ALLY,
			[_effect(AbilityEffect.Kind.RESURRECT, 0)], 4, 20.0)
	var out := AbilityResolver.cast(ctx, healer, rez, hero)
	assert_eq(out.result, R.OK)
	assert_true(hero.alive)
	assert_eq(hero.hp, 30.0)
	assert_eq(hero.mana, 15.0)
	assert_eq(AbilityResolver.validate(ctx, healer, rez, hero), R.INVALID_TARGET, "can't rez the living")


func test_block_doubles_physical_defense_and_reduces_damage_taken() -> void:
	var buff := BuffDef.new()
	buff.id = &"block"
	buff.duration_seconds = 6.0
	buff.modifiers = [StatModifier.make(Stat.Id.PHYS_DEF, 2.0)]
	var effect := _effect(AbilityEffect.Kind.BUFF, 0)
	effect.buff = buff
	var block := _ability(&"block", AbilityDef.TargetType.SELF, [effect])
	hero.stats.phys_def = 50
	var hit := _ability(&"hit", AbilityDef.TargetType.ENEMY, [_effect(AbilityEffect.Kind.DAMAGE, 60)])
	hit.cooldown_seconds = 0
	AbilityResolver.cast(ctx, enemy, hit, hero)
	assert_eq(hero.hp, 60.0, "60 × (1 − 50/150) = 40")
	assert_eq(AbilityResolver.cast(ctx, hero, block, null).result, R.OK, "self target needs no target")
	assert_eq(hero.current_stats(ctx.now).phys_def, 100.0)
	ctx.now = 2.0
	AbilityResolver.cast(ctx, enemy, hit, hero)
	assert_eq(hero.hp, 30.0, "60 × (1 − 100/200) = 30")


func test_ranged_high_ground_bonus() -> void:
	var bolt := _ability(&"bolt", AbilityDef.TargetType.ENEMY, [_effect(AbilityEffect.Kind.DAMAGE, 40)], 5)
	bolt.ranged = true
	enemy.stats.phys_def = 0
	enemy.hp = 60
	ctx.grid.set_tile(hero.tile(), 2, true)
	AbilityResolver.cast(ctx, hero, bolt, enemy)
	assert_eq(enemy.hp, 12.0, "40 × 1.2 = 48")
