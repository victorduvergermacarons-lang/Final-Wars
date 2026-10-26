extends GutTest
## Debug console commands (Milestone 3 §7): run by the host on your own hero,
## refused unless the host allows them.

const ContentDBScript := preload("res://autoload/content_db.gd")

var db
var world: World
var sim: WorldSim
var hero: Hero


func before_all() -> void:
	db = ContentDBScript.new()


func after_all() -> void:
	db.free()


func before_each() -> void:
	world = World.new(db.zones.values(), db.rules, 5, &"greenfields", db.quests)
	world.enable_debug(db)
	hero = world.add_saved_hero(CharacterData.new_character("Dev", db.heroes[&"adventurer"]), db)
	sim = world.zone_of(hero.id)
	hero.move.place(Vector2i(10, 20))


func _run(line: String) -> Dictionary:
	world.submit(hero.id, {"type": "debug", "line": line})
	for e in world.step():
		if e.type == "debug" and e.target == hero.id:
			return e
	return {}


func test_help_lists_the_commands() -> void:
	var r := _run("help")
	assert_true(r.ok)
	for word in ["level", "mastery", "ap", "master", "spawn"]:
		assert_string_contains(r.text, word)


func test_set_level_applies_growth() -> void:
	var hp := hero.stats.hp
	assert_true(_run("level 4").ok)
	assert_eq(hero.level, 4)
	assert_gt(hero.stats.hp, hp, "the sword's growth was applied")
	assert_true(_run("level 2").ok)
	assert_eq(hero.level, 2)


func test_set_mastery() -> void:
	assert_true(_run("mastery fire 350").ok)
	assert_almost_eq(Mastery.permanent(hero, "Fire"), 350.0, 0.01)
	assert_false(_run("mastery lightning 5").ok, "unknown tree")


func test_grant_ap_masters_the_learning_ability() -> void:
	assert_true(_run("ap 25").ok)
	assert_true(hero.is_mastered(&"F01"), "Fire Punch mastered")


func test_master_by_id_or_name() -> void:
	assert_true(_run("master W01").ok)
	assert_true(hero.is_mastered(&"W01"))
	assert_true(_run("master \"Fire Dart\"").ok)
	assert_true(hero.is_mastered(&"F03"))
	assert_false(_run("master Nonsense").ok)


func test_spawn_enemies_at_a_level() -> void:
	var before := sim.enemies().size()
	var r := _run("spawn wolf 4 2")
	assert_true(r.ok, r.text)
	var spawned := sim.enemies().slice(before)
	assert_eq(spawned.size(), 2)
	for e in spawned:
		assert_eq(e.level, 4)
		assert_true(e.temporary)
		assert_gt(e.stats.hp, db.enemies[&"wolf"].stats.hp, "tougher at a higher level")
		assert_eq(TileGeometry.distance(e.tile(), hero.tile()), 1)
	assert_true(_run("spawn \"Bandit Brute\"").ok, "by name, at its own level")
	assert_eq(sim.enemies().back().level, 3)


func test_spawned_enemies_do_not_respawn() -> void:
	_run("spawn wolf")
	var wolf: Enemy = sim.enemies().back()
	var id := wolf.id
	var events: Array[Dictionary] = []
	wolf.threat.add(hero.id, 1.0)
	AbilityResolver.deal_damage(sim.ctx, hero, wolf, &"test", 99999.0, false, events)
	sim._emit_resolved(events)
	world.step()
	assert_not_null(sim.get_actor(id), "its corpse stays while it fades (animated creatures)")
	world.advance(wolf.def.art.corpse_total() + 0.1)
	assert_null(sim.get_actor(id), "removed once its corpse has faded")


func test_refused_when_the_host_does_not_allow_it() -> void:
	world.enable_debug(null)
	world.submit(hero.id, {"type": "debug", "line": "level 10"})
	var events := world.step()
	assert_true(events.any(func(e): return e.type == "rejected" and e.reason == "debug_disabled"))
	assert_eq(hero.level, 1)


func test_game_speed_is_set_by_the_host_and_refused_without_debug() -> void:
	world.submit(hero.id, {"type": "game_speed", "value": 1.5})
	var events := world.step()
	assert_eq(db.rules.game_speed, 1.5)
	assert_true(events.any(func(e): return e.type == "game_speed" and e.value == 1.5))
	world.enable_debug(null)
	world.submit(hero.id, {"type": "game_speed", "value": 0.5})
	events = world.step()
	assert_true(events.any(func(e): return e.type == "rejected" and e.reason == "debug_disabled"))
	assert_eq(db.rules.game_speed, 1.5)
	db.rules.game_speed = 1.0


func test_game_speed_intent_is_clamped() -> void:
	assert_eq(Intents.sanitize({"type": "game_speed", "value": 5}).value, CombatRules.GAME_SPEED_MAX)
	assert_eq(Intents.sanitize({"type": "game_speed", "value": 0.0}).value, CombatRules.GAME_SPEED_MIN)
	assert_eq(Intents.sanitize({"type": "game_speed", "value": "fast"}), {})


func test_intent_shape_is_checked() -> void:
	assert_eq(Intents.sanitize({"type": "debug", "line": 5}), {})
	assert_eq(Intents.sanitize({"type": "debug", "line": "x".repeat(300)}), {})
	assert_eq(Intents.sanitize({"type": "debug", "line": "help"}).line, "help")
