extends GutTest
## The Training Dummy: a practice target by the testing grounds' entrance. Huge
## health, never moves or attacks, can't be knocked back, gives no Mastery, and
## lets a hero out of combat once they walk past its leash radius.

var world: WorldSim
var hero: Hero
var dummy: Enemy
var dummy_def: EnemyDef


func before_each() -> void:
	var zone := ZoneDef.new()
	zone.id = &"plain"
	var rows: PackedStringArray = []
	var walk: PackedStringArray = []
	for y in 20:
		rows.append("0".repeat(20))
		walk.append(".".repeat(20))
	zone.height_rows = rows
	zone.walk_rows = walk
	zone.graveyards = [Vector2i(0, 0)]
	zone.hero_spawns = [Vector2i(0, 0)]
	world = WorldSim.new(zone, ContentDB.rules, 3)
	dummy_def = ContentDB.enemies[&"training_dummy"]
	var hd := HeroDef.new()
	hd.base_stats = StatBlock.make({Stat.Id.HP: 500, Stat.Id.MANA: 500, Stat.Id.MAG_ATK: 20, Stat.Id.JUMP: 2})
	hero = world.add_hero(hd)
	hero.move.place(Vector2i(10, 10))
	dummy = world.add_enemy(dummy_def, Vector2i(11, 10))


func _run(seconds: float) -> Array:
	var events := []
	for i in roundi(seconds / world.rules.tick_seconds):
		events.append_array(world.step())
	return events


func _hit(ability_id: StringName) -> void:
	world.cast(hero, ContentDB.abilities[ability_id], dummy)
	world.step()


func test_data() -> void:
	assert_true(dummy_def.training_dummy)
	assert_gte(dummy_def.stats.hp, 1000000.0, "ridiculously high health")
	assert_true(dummy_def.abilities.is_empty(), "no attacks")
	assert_eq(dummy_def.xp_reward, 0)


func test_takes_hits_and_never_moves_or_attacks() -> void:
	_hit(&"F01") # Fire Punch
	assert_lt(dummy.hp, dummy.stats.hp, "it takes the hit")
	assert_true(hero.in_combat(world.now), "hitting it is a fight (practice under combat rules)")
	var events := _run(10.0)
	assert_eq(dummy.tile(), Vector2i(11, 10), "never moves")
	assert_eq(hero.hp, 500.0, "never attacks")
	assert_false(events.any(func(e): return e.get("source", -1) == dummy.id and e.type in ["damage", "cast_start"]))


func test_knockbacks_dont_move_it() -> void:
	_hit(&"A01") # Air Palm: damage + knockback 1
	assert_eq(dummy.tile(), Vector2i(11, 10))


func test_walking_away_ends_the_fight_and_it_resets() -> void:
	_hit(&"F01")
	assert_true(hero.in_combat(world.now))
	hero.move.place(Vector2i(11 + dummy_def.leash_radius + 2, 10))
	_run(0.5)
	assert_false(hero.in_combat(world.now), "out of combat once past its leash radius")
	_run(0.5)
	assert_eq(dummy.hp, dummy.stats.hp, "back to full health")
	assert_false(dummy.evading, "and targetable again")


func test_no_mastery_from_practice() -> void:
	var h := world.add_saved_hero(CharacterData.new_character("Practice", ContentDB.heroes[&"adventurer"]), ContentDB)
	h.move.place(Vector2i(10, 11))
	dummy.move.place(Vector2i(10, 12))
	var before := Mastery.permanent(h, "Fire")
	for i in 5:
		world.cast(h, ContentDB.abilities[&"F01"], dummy)
		_run(2.5)
	assert_eq(Mastery.permanent(h, "Fire"), before)


func test_stands_by_the_testing_grounds_entrance_not_in_a_pen() -> void:
	var zone: ZoneDef = ContentDB.zones[&"enemy_testing"]
	var spawns := zone.enemy_spawns.filter(func(s): return s.enemy.id == &"training_dummy")
	assert_eq(spawns.size(), 1)
	assert_eq(spawns[0].tile, TestingGrounds.DUMMY)
	assert_lt(spawns[0].tile.x, TestingGrounds.ENTRANCE_WIDTH - 1, "west of the first pen's wall")
	assert_false(zone.landmarks.any(func(l): return l.name.begins_with("Training Dummy")), "no pen sign")
