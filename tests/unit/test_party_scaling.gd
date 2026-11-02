extends GutTest
## Enemies grow with the number of heroes in their zone (CombatRules "Party
## size"): max HP and damage, and a kill's XP so each hero earns a solo share.
## Elites and training dummies don't scale; a fight keeps the size it began with.

var rules: CombatRules
var world: WorldSim
var wolf_def: EnemyDef
var heroes: Array[Hero] = []


func _zone() -> ZoneDef:
	var z := ZoneDef.new()
	z.id = &"field"
	var rows: PackedStringArray = []
	for y in 12:
		rows.append("0".repeat(12))
	z.height_rows = rows
	var walk: PackedStringArray = []
	for y in 12:
		walk.append(".".repeat(12))
	z.walk_rows = walk
	z.hero_spawns = [Vector2i(1, 1)] as Array[Vector2i]
	return z


func before_each() -> void:
	rules = CombatRules.new()
	world = WorldSim.new(_zone(), rules, 5)
	wolf_def = EnemyDef.new()
	wolf_def.id = &"test_wolf"
	wolf_def.stats.hp = 200.0
	wolf_def.stats.phys_atk = 10.0
	wolf_def.xp_reward = 60
	heroes.clear()


func _add_heroes(n: int) -> void:
	for i in n:
		var h := world.add_hero(ContentDB.heroes[&"adventurer"])
		h.move.place(world.find_free_tile_near(Vector2i(1 + heroes.size(), 1)))
		heroes.append(h)


func test_health_and_damage_grow_with_the_heroes_in_the_zone() -> void:
	var wolf := world.add_enemy(wolf_def, Vector2i(9, 9))
	_add_heroes(1)
	world.step()
	assert_eq(wolf.stats.hp, 200.0, "solo: as written")
	assert_eq(wolf.damage_scale, 1.0)
	for n in [2, 3, 4]:
		_add_heroes(1)
		world.step()
		assert_eq(wolf.stats.hp, roundf(200.0 * rules.party_hp_multiplier(n)), "%d heroes" % n)
		assert_eq(wolf.hp, wolf.stats.hp, "at full health")
		assert_almost_eq(wolf.damage_scale, 1.0 + 0.1 * (n - 1), 0.001)
	assert_eq(wolf.stats.hp, 620.0, "four heroes: 3.1x")
	_add_heroes(1)
	world.step()
	assert_eq(wolf.stats.hp, 620.0, "no bigger than for four")


func test_a_hurt_enemy_keeps_its_share_of_health() -> void:
	var wolf := world.add_enemy(wolf_def, Vector2i(9, 9))
	_add_heroes(1)
	world.step()
	wolf.hp = 100.0
	_add_heroes(1)
	world.step()
	assert_almost_eq(wolf.hp, 170.0, 1.0, "half of 340 (plus a tick of regen)")


func test_a_fight_keeps_the_size_it_began_with() -> void:
	var wolf := world.add_enemy(wolf_def, Vector2i(9, 9))
	_add_heroes(2)
	world.step()
	wolf.state = Enemy.State.COMBAT
	wolf.threat.add(heroes[0].id, 1.0)
	_add_heroes(2)
	world.step()
	assert_eq(wolf.party_size, 2, "scaled for the two who started it")


func test_scaled_enemies_hit_harder() -> void:
	var wolf := world.add_enemy(wolf_def, Vector2i(2, 2))
	_add_heroes(4)
	world.step()
	var events: Array[Dictionary] = []
	var hero := heroes[0]
	var before := hero.hp
	AbilityResolver.deal_damage(world.ctx, wolf, hero, &"bite", 10.0, false, events)
	assert_eq(before - hero.hp, 13.0, "1.3x for four heroes")


func test_each_hero_earns_a_solo_share_of_xp() -> void:
	for n in [1, 2, 4]:
		before_each()
		var wolf := world.add_enemy(wolf_def, Vector2i(5, 5))
		_add_heroes(n)
		world.step()
		for h in heroes:
			wolf.threat.add(h.id, 1.0)
		var events: Array[Dictionary] = []
		AbilityResolver.deal_damage(world.ctx, heroes[0], wolf, &"strike", 99999.0, false, events)
		world._emit_resolved(events)
		for h in heroes:
			assert_eq(h.xp, 60.0, "%d heroes: each gets the solo 60 XP" % n)


func test_elites_and_dummies_dont_scale() -> void:
	var boss_def: EnemyDef = wolf_def.duplicate()
	boss_def.elite = true
	var dummy_def: EnemyDef = wolf_def.duplicate()
	dummy_def.training_dummy = true
	var boss := world.add_enemy(boss_def, Vector2i(9, 9))
	var dummy := world.add_enemy(dummy_def, Vector2i(9, 7))
	_add_heroes(4)
	world.step()
	for e in [boss, dummy]:
		assert_eq(e.stats.hp, 200.0)
		assert_eq(e.damage_scale, 1.0)


func test_scaling_can_be_switched_off() -> void:
	rules.party_scaling = false
	var wolf := world.add_enemy(wolf_def, Vector2i(9, 9))
	_add_heroes(4)
	world.step()
	assert_eq(wolf.stats.hp, 200.0)


func test_spawns_can_set_a_level() -> void:
	var z := _zone()
	var s := EnemySpawn.new()
	s.enemy = wolf_def
	s.tile = Vector2i(6, 6)
	s.level = 3
	z.enemy_spawns = [s] as Array[EnemySpawn]
	var w := WorldSim.new(z, rules, 1)
	var e: Enemy = w.enemies()[0]
	assert_eq(e.level, 3)
	assert_eq(e.def.stats.hp, 260.0, "+15% per level above its type's 1")
	assert_eq(e.def.xp_reward, 78)
	assert_eq(e.def.id, &"test_wolf", "still the same kind of enemy (quests count it)")
