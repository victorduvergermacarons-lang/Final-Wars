extends GutTest
## A scripted playthrough with real intents only (what a client sends): walk from
## Millbrook through the gate, fight every enemy in the Enemy Testing Grounds once
## (a debug-levelled hero with Slash, Fire Punch and Healing Touch), use the Reset
## Shrine, and walk back to Millbrook. Prints a short report per fight.

const ContentDBScript := preload("res://autoload/content_db.gd")
const FIGHT_LIMIT := 120.0

var db
var world: World
var hero: Hero


func before_all() -> void:
	db = ContentDBScript.new()


func after_all() -> void:
	db.free()


func _sim() -> WorldSim:
	return world.zone_of(hero.id)


func _tick(seconds: float = 0.05) -> Array:
	return world.advance(seconds)


func _walk_to(goal: Vector2i, max_seconds: float = 90.0) -> bool:
	var t := 0.0
	while hero.tile() != goal and t < max_seconds:
		var sim := _sim()
		var path := Pathfinder.find_path(sim.grid, hero.tile(), goal, 2, sim.occupied_tiles(hero), -1, 20000)
		if path.size() >= 2 and hero.move.can_start_step(hero.in_combat(sim.now), hero.cooldowns, sim.now):
			world.submit(hero.id, {"type": "step", "to": path[1]})
		_tick()
		t += 0.05
	return hero.tile() == goal


func _debug(line: String) -> void:
	world.submit(hero.id, {"type": "debug", "line": line})
	_tick()


## Fights `enemy` until it dies (or the time limit). Returns a report.
func _fight(enemy: Enemy) -> Dictionary:
	var sim := _sim()
	var start := sim.now
	var hp_before := hero.hp
	var used := {}
	var hits := []
	var lowest := hero.hp
	while enemy.alive and sim.now - start < FIGHT_LIMIT and hero.alive:
		var events := []
		var stats := hero.current_stats(sim.now)
		if hero.hp < stats.hp * 0.45:
			world.submit(hero.id, {"type": "cast", "ability": &"W01", "target": hero.id})
		var d := TileGeometry.range_distance(hero.tile(), enemy.tile())
		if d <= 1:
			var dir := enemy.tile() - hero.tile()
			world.submit(hero.id, {"type": "face", "dir": dir})
			world.submit(hero.id, {"type": "cast", "ability": &"S01", "target": enemy.id})
			world.submit(hero.id, {"type": "cast", "ability": &"F01", "target": enemy.id})
		elif d <= 3 and hero.cooldowns.ability_remaining(&"W02", sim.now) <= 0.0 and hero.cooldowns.gcd_remaining(sim.now) <= 0.0:
			world.submit(hero.id, {"type": "cast", "ability": &"W02", "target": enemy.id})
		elif hero.move.can_start_step(hero.in_combat(sim.now), hero.cooldowns, sim.now):
			var blocked := sim.occupied_tiles(hero)
			blocked.erase(enemy.tile())
			var path := Pathfinder.find_path(sim.grid, hero.tile(), enemy.tile(), 2, blocked, -1, 4000)
			if path.size() >= 3:
				world.submit(hero.id, {"type": "step", "to": path[1]})
		events = _tick()
		lowest = minf(lowest, hero.hp)
		for e in events:
			if e.get("source", -1) == enemy.id and e.has("ability"):
				used[e.ability] = true
			if e.get("source", -1) == enemy.id and e.get("target", -1) == hero.id and e.type in ["damage", "miss"]:
				hits.append("%s %s %s" % [e.get("ability", "?"), e.type, e.get("amount", "")])
	return {"enemy": enemy.def.id, "won": not enemy.alive, "seconds": snappedf(sim.now - start, 0.1),
			"hp_lost": roundi(hp_before - lowest), "enemy_abilities": used.keys(), "hits_on_hero": hits}


func test_walk_in_fight_everything_and_walk_back() -> void:
	world = World.new(db.zones.values(), db.rules, 7, &"town")
	world.enable_debug(db)
	hero = world.add_saved_hero(CharacterData.new_character("Tester", db.heroes[&"adventurer"]), db)
	_debug("level 12")
	_debug("master W01")
	_debug("master W02")
	_debug("heal")

	# Millbrook -> the gate -> Enemy Testing Grounds.
	assert_true(_walk_to(Vector2i(16, 0)), "walked to Millbrook's north-east gate")
	world.submit(hero.id, {"type": "step", "to": Vector2i(16, -1)})
	_tick(0.3)
	assert_eq(_sim().zone.id, &"enemy_testing", "through the gate")

	var reports := []
	var road: int = _sim().zone.landmarks[0].tile.y + 1
	for spawn in _sim().zone.enemy_spawns:
		var enemy: Enemy = _sim().enemies().filter(func(e): return e.spawn_tile == spawn.tile)[0]
		_debug("heal")
		if spawn.enemy.elite:
			_debug("level 40") # bosses are built for a group
		assert_true(_walk_to(Vector2i(spawn.tile.x, road)), "walked the road to the %s pen" % spawn.enemy.id)
		assert_eq(enemy.state, Enemy.State.IDLE, "%s waits in its pen" % spawn.enemy.id)
		var r := _fight(enemy)
		reports.append(r)
		gut.p("Fight: %s" % str(r))
		assert_true(r.won, "beat the %s: %s" % [spawn.enemy.id, r])
		for other in _sim().enemies():
			if other != enemy:
				assert_ne(other.state, Enemy.State.COMBAT, "%s stayed out of the %s fight" % [other.def.id, spawn.enemy.id])
		# Back onto the road, out of the pen, before the enemy respawns.
		assert_true(_walk_to(Vector2i(spawn.tile.x, road)), "back on the road")

	# Every killed enemy is back 10 s later.
	_tick(10.5)
	for e in _sim().enemies():
		assert_true(e.alive, "%s respawned" % e.def.id)

	# The Reset Shrine, then back to Millbrook.
	var shrine: Npc = null
	for id in _sim().ctx.actors:
		if _sim().ctx.actors[id] is Npc:
			shrine = _sim().ctx.actors[id]
	assert_true(_walk_to(shrine.tile() + Vector2i(0, 1)), "walked back to the shrine")
	world.submit(hero.id, {"type": "talk", "npc": shrine.id})
	var events := _tick()
	assert_true(events.any(func(e): return e.type == "zone_reset"), "the shrine resets the grounds")
	var gate := Vector2i(TestingGrounds.GATE[0], _sim().zone.get_depth() - 1)
	assert_true(_walk_to(gate), "walked to the gate home")
	world.submit(hero.id, {"type": "step", "to": gate + Vector2i(0, 1)})
	_tick(0.3)
	assert_eq(_sim().zone.id, &"town", "back in Millbrook")
	assert_eq(hero.tile().y, 0, "at the gate")
