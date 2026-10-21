extends GutTest
## World: zones without heroes sleep (only their clock runs) and wake when a hero
## arrives; timers that ran out meanwhile resolve on the first tick after.

const ContentDBScript := preload("res://autoload/content_db.gd")

var db
var world: World
var hero: Hero
var rules: CombatRules


func before_all() -> void:
	db = ContentDBScript.new()


func after_all() -> void:
	db.free()


func before_each() -> void:
	rules = db.rules.duplicate()
	rules.empty_zone_sleep_seconds = 5.0
	world = World.new(db.zones.values(), rules, 1, &"town")
	hero = world.add_saved_hero(CharacterData.new_character("Zed", db.heroes[&"adventurer"]), db)


func _wolf(zone: StringName) -> Enemy:
	return world.zone(zone).enemies().filter(func(e): return e.def.id == &"wolf")[0]


func test_empty_zones_fall_asleep_after_the_wait() -> void:
	world.advance(4.0)
	assert_false(world.is_asleep(&"greenfields"), "still settling")
	world.advance(1.5)
	assert_true(world.is_asleep(&"greenfields"))
	assert_true(world.is_asleep(&"enemy_testing"))
	assert_false(world.is_asleep(&"town"), "the hero is here")


func test_clocks_stay_together() -> void:
	world.advance(12.0)
	for id in world.zone_ids():
		assert_almost_eq(world.zone(id).now, world.now, 0.0001, "%s keeps time" % id)


func test_nothing_acts_while_asleep() -> void:
	world.advance(6.0)
	var grizzle: Enemy = world.zone(&"greenfields").enemies().filter(
			func(e): return not e.patrol.is_empty())[0]
	var at := grizzle.tile()
	world.advance(10.0)
	assert_eq(grizzle.tile(), at, "the patrol waits")


func test_timers_run_out_while_asleep_and_resolve_on_waking() -> void:
	world.advance(6.0)
	var sim := world.zone(&"greenfields")
	var wolf := _wolf(&"greenfields")
	wolf.alive = false
	wolf.hp = 0.0
	wolf.state = Enemy.State.DEAD
	wolf.respawn_at = sim.now + 1.0
	world.advance(3.0)
	assert_false(wolf.alive, "asleep: no respawn yet")
	world.move_hero(hero.id, &"greenfields", Vector2i(15, 15))
	world.step()
	assert_false(world.is_asleep(&"greenfields"))
	assert_true(wolf.alive, "respawned on the first tick awake")


func test_a_zone_left_behind_settles_before_sleeping() -> void:
	world.move_hero(hero.id, &"greenfields", Vector2i(15, 15))
	world.advance(1.0)
	world.move_hero(hero.id, &"town", Vector2i(9, 9))
	world.advance(3.0)
	assert_false(world.is_asleep(&"greenfields"), "still running for the wait")
	world.advance(3.0)
	assert_true(world.is_asleep(&"greenfields"))


func test_negative_wait_never_sleeps() -> void:
	rules.empty_zone_sleep_seconds = -1.0
	world.advance(20.0)
	for id in world.zone_ids():
		assert_false(world.is_asleep(id))
