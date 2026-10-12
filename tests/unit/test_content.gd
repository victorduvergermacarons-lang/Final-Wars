extends GutTest
## The shipped content loads and is valid.

const ContentDBScript := preload("res://autoload/content_db.gd")

var db


func before_all() -> void:
	db = ContentDBScript.new()


func after_all() -> void:
	db.free()


func test_all_content_validates() -> void:
	assert_eq(db.validate(), PackedStringArray())


func test_starter_items_teach_the_agreed_abilities() -> void:
	var teaches := func(id): return db.items[id].teaches.map(func(a): return a.id)
	assert_eq(teaches.call(&"sword"), [&"strike"])
	assert_eq(teaches.call(&"staff"), [&"fireball"])
	assert_eq(teaches.call(&"shield"), [&"block"])
	assert_eq(teaches.call(&"holy_charm"), [&"heal", &"resurrect"])


func test_items_share_ability_resources() -> void:
	assert_same(db.items[&"sword"].teaches[0], db.abilities[&"strike"])


func test_block_doubles_physical_defense_off_the_gcd() -> void:
	var block: AbilityDef = db.abilities[&"block"]
	var buff: BuffDef = block.effects[0].buff
	assert_eq(buff.modifiers[0].stat, Stat.Id.PHYS_DEF)
	assert_eq(buff.modifiers[0].multiplier, 2.0)
	assert_false(block.on_gcd, "Block neither waits for nor triggers the GCD")


func test_zone_is_30_by_30_with_heights_and_enemies() -> void:
	var zone: ZoneDef = db.zones[&"greenfields"]
	var grid := GridModel.from_zone(zone)
	assert_eq(grid.width, 30)
	assert_eq(grid.depth, 30)
	assert_eq(grid.height_at(Vector2i(25, 5)), 4, "plateau")
	assert_eq(zone.enemy_spawns.size(), 10)
	var counts := {}
	for s in zone.enemy_spawns:
		counts[s.enemy.id] = counts.get(s.enemy.id, 0) + 1
		assert_true(grid.is_walkable(s.tile))
		var path := Pathfinder.find_path(grid, zone.hero_spawns[0], s.tile, 2, {}, -1, 100000)
		assert_false(path.is_empty(), "%s at %s is reachable" % [s.enemy.id, s.tile])
	assert_eq(counts, {&"wolf": 4, &"goblin_shaman": 2, &"bandit_brute": 2, &"fen_skirmisher": 2})


func test_plateau_is_reachable_by_ramp_only() -> void:
	var zone: ZoneDef = db.zones[&"greenfields"]
	var grid := GridModel.from_zone(zone)
	var path := Pathfinder.find_path(grid, zone.hero_spawns[0], Vector2i(26, 5), 2, {}, -1, 100000)
	assert_false(path.is_empty())
	assert_true(path.has(Vector2i(24, 10)) or path.has(Vector2i(25, 10)), "climbs the ramp")


func test_world_starts_from_shipped_content() -> void:
	var world := WorldSim.new(db.zones[&"greenfields"], db.rules, 1)
	var hero := world.add_hero(db.heroes[&"adventurer"])
	assert_eq(world.enemies().size(), 10)
	assert_eq(hero.available_abilities().map(func(a): return a.id), [&"strike", &"heal", &"resurrect"])
	world.advance(1.0)
	assert_true(hero.alive)


func test_enemy_types_levels_and_behaviors() -> void:
	var expect := {
		&"wolf": [1, EnemyDef.Behavior.MELEE],
		&"goblin_shaman": [2, EnemyDef.Behavior.KITER],
		&"bandit_brute": [3, EnemyDef.Behavior.MELEE],
		&"fen_skirmisher": [4, EnemyDef.Behavior.FLANKER],
	}
	for id in expect:
		var def: EnemyDef = db.enemies[id]
		assert_eq(def.level, expect[id][0], "%s level" % id)
		assert_eq(def.behavior, expect[id][1], "%s behavior" % id)
		assert_not_null(def.loot, "%s has loot" % id)
		assert_eq(def.abilities.size(), 1)
	assert_gt(db.enemies[&"bandit_brute"].combat_step_seconds, 1.5, "Brute is slower than a hero")
	assert_lt(db.enemies[&"fen_skirmisher"].combat_step_seconds, db.enemies[&"wolf"].combat_step_seconds,
			"Skirmisher is the fastest")
	var bolt: AbilityDef = db.enemies[&"goblin_shaman"].abilities[0]
	assert_eq(bolt.shape, AbilityDef.Shape.LINE)
	assert_true(bolt.ranged)
	assert_eq(bolt.effects[0].damage_type, AbilityEffect.DamageType.MAGICAL)
