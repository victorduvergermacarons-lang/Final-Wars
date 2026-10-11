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


func test_zone_is_30_by_30_with_heights_and_wolves() -> void:
	var zone: ZoneDef = db.zones[&"greenfields"]
	var grid := GridModel.from_zone(zone)
	assert_eq(grid.width, 30)
	assert_eq(grid.depth, 30)
	assert_eq(grid.height_at(Vector2i(25, 5)), 4, "plateau")
	assert_eq(zone.enemy_spawns.size(), 5)
	for s in zone.enemy_spawns:
		assert_eq(s.enemy.id, &"wolf")
		assert_true(grid.is_walkable(s.tile))


func test_plateau_is_reachable_by_ramp_only() -> void:
	var zone: ZoneDef = db.zones[&"greenfields"]
	var grid := GridModel.from_zone(zone)
	var path := Pathfinder.find_path(grid, zone.hero_spawns[0], Vector2i(26, 5), 2, {}, -1, 100000)
	assert_false(path.is_empty())
	assert_true(path.has(Vector2i(24, 10)) or path.has(Vector2i(25, 10)), "climbs the ramp")


func test_world_starts_from_shipped_content() -> void:
	var world := WorldSim.new(db.zones[&"greenfields"], db.rules, 1)
	var hero := world.add_hero(db.heroes[&"adventurer"])
	assert_eq(world.enemies().size(), 5)
	assert_eq(hero.available_abilities().map(func(a): return a.id), [&"strike", &"heal", &"resurrect"])
	world.advance(1.0)
	assert_true(hero.alive)
