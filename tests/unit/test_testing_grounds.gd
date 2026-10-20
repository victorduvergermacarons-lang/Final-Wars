extends GutTest
## The enemy testing map (TestingGrounds): built from the enemy data, spaced so
## fights never pull a neighbour, 10 s respawns, the Reset Shrine, and the gate
## to and from Millbrook for every player.

const ContentDBScript := preload("res://autoload/content_db.gd")

var db
var zone: ZoneDef


func before_all() -> void:
	db = ContentDBScript.new()
	zone = db.zones[&"enemy_testing"]


func after_all() -> void:
	db.free()


func _road() -> int:
	return zone.landmarks[0].tile.y + 1


func _strong_hero(sim: WorldSim) -> Hero:
	var hd := HeroDef.new()
	hd.base_stats = StatBlock.make({Stat.Id.HP: 100000, Stat.Id.JUMP: 2})
	return sim.add_hero(hd)


func test_every_enemy_type_has_exactly_one_pen() -> void:
	var count := {}
	for s in zone.enemy_spawns:
		count[s.enemy.id] = count.get(s.enemy.id, 0) + 1
	for id in db.enemies:
		assert_eq(count.get(id, 0), 1, "%s has a pen" % id)
	assert_true(count.has(&"salamander_hound"))
	var signs := zone.landmarks.map(func(l): return l.name)
	for s in zone.enemy_spawns:
		assert_true(signs.has("%s (Lv %d)" % [s.enemy.display_name, s.enemy.level]), "sign for %s" % s.enemy.id)


func test_an_enemy_added_later_gets_a_pen() -> void:
	var extra := EnemyDef.new()
	extra.id = &"zz_new_enemy"
	extra.display_name = "New Enemy"
	var z := ZoneDef.new()
	z.id = &"t"
	TestingGrounds.build(z, db.enemies.values() + [extra])
	assert_true(z.enemy_spawns.any(func(s): return s.enemy == extra))
	assert_eq(z.enemy_spawns.size(), db.enemies.size() + 1)


func test_spacing_keeps_every_fight_away_from_the_neighbours() -> void:
	var spawns := zone.enemy_spawns
	for a in spawns:
		for b in spawns:
			if a == b:
				continue
			var d := GridModel.distance(a.tile, b.tile)
			assert_gte(d, TestingGrounds.reach(a.enemy) + b.enemy.aggro_radius + TestingGrounds.MARGIN,
					"%s's fight stays out of %s's sight" % [a.enemy.id, b.enemy.id])
			assert_gte(d, a.enemy.leash_radius + a.enemy.pack_call_radius + TestingGrounds.MARGIN,
					"%s's call can't reach %s" % [a.enemy.id, b.enemy.id])


func test_the_road_and_the_entrance_never_aggro_anyone() -> void:
	var road := _road()
	for s in zone.enemy_spawns:
		for x in zone.get_width():
			assert_gt(GridModel.distance(s.tile, Vector2i(x, road)), s.enemy.aggro_radius)
		for p in zone.hero_spawns + zone.graveyards + zone.npcs.map(func(n): return n.tile):
			assert_gt(GridModel.distance(s.tile, p), TestingGrounds.reach(s.enemy), "entrance %s is safe from %s" % [p, s.enemy.id])


func test_bosses_are_in_their_own_arena_at_the_far_end() -> void:
	var arena: ZoneLandmark = zone.landmarks.filter(func(l): return l.name == "Boss Arena")[0]
	for s in zone.enemy_spawns:
		if s.enemy.elite:
			assert_gt(s.tile.x, arena.tile.x, "%s is in the arena" % s.enemy.id)
		else:
			assert_lt(s.tile.x, arena.tile.x, "%s is outside the arena" % s.enemy.id)
	# The arena hedge only opens on the road.
	var grid := GridModel.from_zone(zone)
	var open := []
	for y in grid.depth:
		if grid.is_walkable(Vector2i(arena.tile.x, y)):
			open.append(y)
	assert_eq(open, [_road(), _road() + 1])


func test_walking_the_whole_road_pulls_nobody() -> void:
	var sim := WorldSim.new(zone, db.rules, 1)
	var hero := _strong_hero(sim)
	var road := _road()
	hero.move.place(Vector2i(1, road))
	for x in range(2, zone.get_width() - 1):
		sim.submit(hero.id, {"type": "step", "to": Vector2i(x, road)})
		for i in 5:
			sim.step()
	assert_eq(hero.tile().x, zone.get_width() - 2, "walked to the far end")
	for e in sim.enemies():
		assert_eq(e.state, Enemy.State.IDLE, "%s stayed put" % e.def.id)


## Pulls each enemy as far as its leash lets it, both ways along the line,
## standing right next to it: no other enemy may join.
func test_pulling_one_enemy_to_its_leash_never_pulls_another() -> void:
	for spawn in zone.enemy_spawns:
		for dir in [Vector2i(1, 0), Vector2i(-1, 0)]:
			var sim := WorldSim.new(zone, db.rules, 2)
			var hero := _strong_hero(sim)
			var target: Enemy = sim.enemies().filter(func(e): return e.spawn_tile == spawn.tile)[0]
			target.threat.add(hero.id, 1.0)
			var spot: Vector2i = spawn.tile + Vector2i(0, 1)
			var farthest := 0
			var evaded := false
			for k in spawn.enemy.leash_radius + 4:
				var next: Vector2i = spot + dir
				if sim.grid.is_walkable(next):
					spot = next
				hero.move.place(sim.find_free_tile_near(spot))
				for i in 30:
					sim.step()
					farthest = maxi(farthest, GridModel.distance(target.tile(), spawn.tile))
				if target.state != Enemy.State.COMBAT:
					evaded = true
					break
			assert_true(evaded or farthest >= spawn.enemy.leash_radius - 3,
					"%s was really pulled %s (%d tiles)" % [spawn.enemy.id, dir, farthest])
			for e in sim.enemies():
				if e != target:
					assert_eq(e.state, Enemy.State.IDLE, "pulling %s %s left %s alone" % [spawn.enemy.id, dir, e.def.id])
					assert_true(e.threat.is_empty())


func test_killed_enemies_respawn_in_10_seconds() -> void:
	assert_eq(zone.enemy_respawn_seconds, 10.0)
	var sim := WorldSim.new(zone, db.rules, 3)
	var hero := _strong_hero(sim)
	hero.move.place(Vector2i(2, _road()))
	var wolf: Enemy = sim.enemies().filter(func(e): return e.def.id == &"wolf")[0]
	wolf.threat.add(hero.id, 1.0)
	wolf.hp = 1.0
	var hit := AbilityDef.new()
	hit.id = &"t_hit"
	hit.targeting = AbilityDef.TargetingMode.TARGETED
	hit.max_range = 999
	hit.requires_line_of_sight = false
	var fx := AbilityEffect.new()
	fx.base_amount = 50.0
	fx.can_crit = false
	hit.effects = [fx] as Array[AbilityEffect]
	sim.cast(hero, hit, wolf)
	assert_false(wolf.alive)
	for i in roundi(9.5 / db.rules.tick_seconds):
		sim.step()
	assert_false(wolf.alive, "still dead at 9.5 s")
	for i in roundi(1.0 / db.rules.tick_seconds):
		sim.step()
	assert_true(wolf.alive, "back at 10 s")
	assert_eq(wolf.tile(), wolf.spawn_tile)


func test_reset_shrine_puts_everything_back() -> void:
	var sim := WorldSim.new(zone, db.rules, 4)
	var hero := _strong_hero(sim)
	var shrine: Npc = null
	for id in sim.ctx.actors:
		if sim.ctx.actors[id] is Npc:
			shrine = sim.ctx.actors[id]
	assert_not_null(shrine)
	assert_true(shrine.def.resets_zone)
	var enemies := sim.enemies()
	enemies[0].hp = 5.0
	enemies[0].move.place(enemies[0].spawn_tile + Vector2i(0, 2))
	enemies[1].die()
	enemies[2].threat.add(hero.id, 10.0)
	enemies[2].state = Enemy.State.COMBAT
	hero.combat_until = sim.now + 100.0
	var chill: BuffDef = db.buffs[&"frost_shard_chill"]
	hero.buffs.apply(chill, sim.now)
	assert_true(hero.buffs.has(chill.id, sim.now))
	var trail: AbilityDef = db.abilities[&"ember_trail"]
	var events: Array[Dictionary] = []
	AbilityResolver.apply_area_effects(sim.ctx, enemies[3], trail, [Vector2i(10, 10)], events)
	sim._handle_requests()
	assert_eq(sim.ground_zones().size(), 1)
	hero.move.place(shrine.tile() + Vector2i(1, 0))
	sim.submit(hero.id, {"type": "talk", "npc": shrine.id})
	var out := sim.step()
	assert_true(out.any(func(e): return e.type == "zone_reset"))
	for e in sim.enemies():
		assert_true(e.alive, "%s alive" % e.def.id)
		assert_eq(e.hp, e.stats.hp, "%s at full health" % e.def.id)
		assert_eq(e.tile(), e.spawn_tile, "%s in its pen" % e.def.id)
		assert_eq(e.state, Enemy.State.IDLE)
	assert_eq(sim.ground_zones().size(), 0, "embers gone")
	assert_false(hero.in_combat(sim.now), "out of combat")
	assert_false(hero.buffs.has(chill.id, sim.now), "debuffs cleared")


func test_two_players_walk_to_the_testing_grounds_and_back() -> void:
	var world := World.new(db.zones.values(), db.rules, 5, &"town")
	var heroes: Array[Hero] = []
	for name in ["Ana", "Bo"]:
		heroes.append(world.add_saved_hero(CharacterData.new_character(name, db.heroes[&"adventurer"]), db))
	var gate := [Vector2i(15, 0), Vector2i(16, 0)]
	for i in heroes.size():
		var h := heroes[i]
		var sim := world.zone_of(h.id)
		var path := Pathfinder.find_path(sim.grid, h.tile(), gate[i], 2, {}, -1, 10000)
		assert_false(path.is_empty(), "%s can reach the gate" % h.display_name)
		for k in range(1, path.size()):
			world.submit(h.id, {"type": "step", "to": path[k]})
			world.advance(db.rules.walk_tile_seconds + 0.05)
		world.submit(h.id, {"type": "step", "to": gate[i] + Vector2i(0, -1)})
		world.advance(0.3)
		assert_eq(world.zone_of(h.id).zone.id, &"enemy_testing", "%s arrived" % h.display_name)
		assert_eq(h.tile().y, zone.get_depth() - 1, "on the gate")
	for i in heroes.size():
		var h := heroes[i]
		var at := h.tile()
		world.submit(h.id, {"type": "step", "to": at + Vector2i(0, 1)})
		world.advance(0.3)
		assert_eq(world.zone_of(h.id).zone.id, &"town", "%s is back in Millbrook" % h.display_name)
		assert_true(gate.has(h.tile()) or gate.any(func(g): return GridModel.distance(g, h.tile()) <= 2),
				"back at the gate (%s)" % h.tile())
