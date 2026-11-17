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
