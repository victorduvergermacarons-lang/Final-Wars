extends GutTest
## WoW-style tanking in the sim: an enemy changes target only when someone passes
## 110% of its target's threat in melee range or 130% farther away
## (EnemyBrain.pick_target, from this tick's positions); a taunt forces it for a while
## and ends early if the taunter dies; heroes' threat grows with Physical Defense.

var db
var world: WorldSim
var tank: Hero
var dps: Hero
var wolf: Enemy

const ContentDBScript := preload("res://autoload/content_db.gd")


func before_all() -> void:
	db = ContentDBScript.new()


func after_all() -> void:
	db.free()


func _hero(def_stat: float) -> Hero:
	var hd := HeroDef.new()
	hd.base_stats = StatBlock.make({Stat.Id.HP: 500, Stat.Id.MANA: 500, Stat.Id.PHYS_DEF: def_stat})
	return world.add_hero(hd)


func before_each() -> void:
	world = WorldSim.new(db.zones[&"greenfields"], db.rules, 3)
	for e in world.enemies():
		world.remove_enemy(e.id)
	tank = _hero(0.0)
	dps = _hero(0.0)
	wolf = world.add_enemy(db.enemies[&"wolf"], Vector2i(10, 20))
	tank.move.place(Vector2i(11, 20)) # beside the wolf
	dps.move.place(Vector2i(16, 20)) # 5 tiles away


func test_a_ranged_hero_needs_130_percent_a_melee_one_110() -> void:
	wolf.threat.add(tank.id, 100)
	assert_eq(EnemyBrain.pick_target(world, wolf), tank.id)
	wolf.threat.add(dps.id, 125)
	assert_eq(EnemyBrain.pick_target(world, wolf), tank.id, "125% from 5 tiles away")
	dps.move.place(Vector2i(10, 21)) # now in melee range
	assert_eq(EnemyBrain.pick_target(world, wolf), dps.id, "125% in melee range")


func test_the_brain_attacks_the_picked_target() -> void:
	wolf.state = Enemy.State.COMBAT
	wolf.threat.add(tank.id, 100)
	world.step() # the tank pulled it: its target
	wolf.threat.add(dps.id, 120) # not enough from range
	for i in 10:
		world.step()
	assert_eq(wolf.threat.target(), tank.id)


func test_a_dead_taunter_ends_the_forced_time() -> void:
	wolf.threat.add(dps.id, 100)
	wolf.threat.taunt(tank.id, 10.0, world.now, 5.0)
	assert_eq(EnemyBrain.pick_target(world, wolf), tank.id)
	tank.die()
	world._on_death(tank) # what a killing blow does: off every threat table
	assert_false(wolf.threat.has(tank.id))
	assert_eq(EnemyBrain.pick_target(world, wolf), dps.id)


# --- Physical Defense raises heroes' threat ----------------------------------------------

func _damage(source: Actor, amount: float, threat_multiplier := 1.0) -> void:
	var events: Array[Dictionary] = []
	AbilityResolver.deal_damage(world.ctx, source, wolf, &"test", amount, false, events, "", threat_multiplier)


func test_threat_grows_with_physical_defense() -> void:
	var rules: CombatRules = world.rules
	var cloth := _hero(10.0)
	var plate := _hero(60.0)
	_damage(cloth, 10.0)
	_damage(plate, 10.0)
	assert_almost_eq(wolf.threat.get_threat(cloth.id), 10.0 * (1.0 + 10.0 / rules.threat_def_divisor), 0.001)
	assert_almost_eq(wolf.threat.get_threat(plate.id), 10.0 * (1.0 + 60.0 / rules.threat_def_divisor), 0.001)
	assert_almost_eq(AbilityResolver.defense_threat_multiplier(world.ctx, plate), 2.5, 0.001,
			"a geared tank (60 Physical Defense) at about 2.5x")


func test_the_multiplier_is_capped() -> void:
	var wall := _hero(500.0)
	assert_eq(AbilityResolver.defense_threat_multiplier(world.ctx, wall), world.rules.max_def_threat_multiplier)


func test_buffs_count_while_up() -> void:
	var h := _hero(20.0)
	var before := AbilityResolver.defense_threat_multiplier(world.ctx, h)
	h.buffs.apply(db.buffs[&"tidal_blessing"], world.now) # +20 Physical Defense
	assert_gt(AbilityResolver.defense_threat_multiplier(world.ctx, h), before)


func test_effect_multiplier_stacks_and_enemies_dont_get_it() -> void:
	var plate := _hero(60.0)
	_damage(plate, 10.0, 3.0)
	assert_almost_eq(wolf.threat.get_threat(plate.id), 10.0 * 2.5 * 3.0, 0.001)
	assert_eq(AbilityResolver.defense_threat_multiplier(world.ctx, wolf), 1.0)


func test_healing_threat_grows_with_physical_defense_too() -> void:
	var healer := _hero(60.0)
	wolf.threat.add(tank.id, 10.0) # fighting the tank
	tank.hp = 100.0
	var heal := AbilityDef.new()
	heal.id = &"test_heal"
	heal.target = AbilityDef.TargetType.ALLY
	heal.max_range = 10
	var e := AbilityEffect.new()
	e.kind = AbilityEffect.Kind.HEAL
	e.base_amount = 40.0
	heal.effects = [e]
	var events: Array[Dictionary] = []
	AbilityResolver.apply_effects(world.ctx, healer, heal, tank, events)
	var healed: float = events.filter(func(x): return x.type == "heal")[0].amount
	assert_almost_eq(wolf.threat.get_threat(healer.id), healed * world.rules.heal_threat_multiplier * 2.5, 0.01)
