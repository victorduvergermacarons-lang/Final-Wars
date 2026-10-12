extends GutTest
## Per-type enemy AI: MELEE chaser, KITER (keeps distance, shoots in a line),
## FLANKER (strikes from the side or back).

var rules: CombatRules
var world: WorldSim
var hero: Hero
var enemy: Enemy


func _ability(shape: AbilityDef.Shape, max_range: int, cooldown: float) -> AbilityDef:
	var e := AbilityEffect.new()
	e.base_amount = 5
	var ab := AbilityDef.new()
	ab.id = &"attack"
	ab.shape = shape
	ab.max_range = max_range
	ab.cooldown_seconds = cooldown
	ab.effects = [e]
	if shape == AbilityDef.Shape.LINE:
		ab.ranged = true
	return ab


func _setup(behavior: EnemyDef.Behavior, ability: AbilityDef, enemy_tile: Vector2i, hero_tile: Vector2i,
		step_seconds: float = 0.5, patrol: Array[Vector2i] = []) -> void:
	rules = CombatRules.new()
	var zone := ZoneDef.new()
	zone.id = &"test"
	var heights: PackedStringArray = []
	var walk: PackedStringArray = []
	for y in 15:
		heights.append("000000000000000")
		walk.append("...............")
	zone.height_rows = heights
	zone.walk_rows = walk
	zone.graveyards = [Vector2i(0, 14)]
	zone.hero_spawns = [hero_tile]
	var def := EnemyDef.new()
	def.id = &"foe"
	def.behavior = behavior
	def.stats = StatBlock.make({Stat.Id.HP: 500, Stat.Id.PHYS_ATK: 10, Stat.Id.MAG_ATK: 10,
			Stat.Id.ACCURACY: 100, Stat.Id.JUMP: 1})
	def.abilities = [ability]
	def.aggro_radius = 6
	def.leash_radius = 20
	def.combat_step_seconds = step_seconds
	var spawn := EnemySpawn.new()
	spawn.enemy = def
	spawn.tile = enemy_tile
	spawn.patrol = patrol
	zone.enemy_spawns = [spawn]
	var hero_def := HeroDef.new()
	hero_def.base_stats = StatBlock.make({Stat.Id.HP: 5000, Stat.Id.JUMP: 2})
	world = WorldSim.new(zone, rules, 7)
	enemy = world.enemies()[0]
	hero = world.add_hero(hero_def)


func _casts(events: Array) -> Array:
	return events.filter(func(e): return e.type == "cast" and e.get("source") == enemy.id)


func test_kiter_backs_off_when_a_hero_is_close() -> void:
	_setup(EnemyDef.Behavior.KITER, _ability(AbilityDef.Shape.LINE, 5, 2.0), Vector2i(7, 7), Vector2i(6, 7))
	world.advance(1.5)
	assert_gt(GridModel.distance(enemy.tile(), hero.tile()), enemy.def.keep_away_distance,
			"stepped out of reach")


func test_kiter_lines_up_and_shoots() -> void:
	_setup(EnemyDef.Behavior.KITER, _ability(AbilityDef.Shape.LINE, 5, 2.0), Vector2i(7, 7), Vector2i(4, 5))
	var events := world.advance(3.0)
	assert_false(_casts(events).is_empty(), "cast a bolt")
	var dmg := events.filter(func(e): return e.type == "damage" and e.get("target") == hero.id)
	assert_false(dmg.is_empty(), "the bolt hit")
	assert_gt(GridModel.distance(enemy.tile(), hero.tile()), enemy.def.keep_away_distance)


func test_flanker_attacks_from_side_or_back() -> void:
	_setup(EnemyDef.Behavior.FLANKER, _ability(AbilityDef.Shape.FRONT, 1, 1.5), Vector2i(7, 9), Vector2i(7, 5))
	hero.face(Vector2i.DOWN) # facing the skirmisher as it comes in
	var flanks := []
	for i in 80:
		for e in world.step():
			if e.type == "cast" and e.get("source") == enemy.id:
				flanks.append(CombatMath.flank(enemy.tile(), hero.tile(), hero.facing))
	assert_false(flanks.is_empty(), "attacked")
	assert_ne(flanks[0], CombatMath.Flank.FRONT, "first strike came from the side or back")


func test_flanker_fights_head_on_when_boxed_in() -> void:
	_setup(EnemyDef.Behavior.FLANKER, _ability(AbilityDef.Shape.FRONT, 1, 1.5), Vector2i(1, 0), Vector2i(1, 1))
	hero.face(Vector2i.UP)
	# Hero in a corridor: block both sides and the back with walls.
	for t in [Vector2i(0, 1), Vector2i(2, 1), Vector2i(1, 2), Vector2i(0, 0), Vector2i(2, 0)]:
		world.grid.set_tile(t, 0, false)
	var events := world.advance(2.0)
	assert_false(_casts(events).is_empty(), "attacked from the front rather than standing still")


func test_melee_chases_and_attacks() -> void:
	_setup(EnemyDef.Behavior.MELEE, _ability(AbilityDef.Shape.FRONT, 1, 1.5), Vector2i(7, 7), Vector2i(7, 3))
	var events := world.advance(4.0)
	assert_false(_casts(events).is_empty())
	assert_eq(GridModel.distance(enemy.tile(), hero.tile()), 1)


func test_patrol_walks_the_loop_while_idle() -> void:
	var route: Array[Vector2i] = [Vector2i(10, 10), Vector2i(13, 10), Vector2i(13, 13)]
	_setup(EnemyDef.Behavior.MELEE, _ability(AbilityDef.Shape.FRONT, 1, 1.5), Vector2i(10, 10), Vector2i(0, 0),
			0.5, route)
	enemy.def.patrol_step_seconds = 0.5
	var seen := {}
	for i in 200: # 10 s
		world.step()
		seen[enemy.tile()] = true
	assert_true(seen.has(Vector2i(13, 10)) and seen.has(Vector2i(13, 13)), "visited the waypoints")
	assert_eq(enemy.state, Enemy.State.IDLE)
	assert_almost_eq(enemy.move.duration, 0.5, 0.001, "walks at the patrol pace")


func test_patroller_leashes_to_where_it_was_pulled_then_resumes() -> void:
	var route: Array[Vector2i] = [Vector2i(10, 10), Vector2i(13, 10)]
	_setup(EnemyDef.Behavior.MELEE, _ability(AbilityDef.Shape.FRONT, 1, 1.5), Vector2i(10, 10), Vector2i(0, 0),
			0.5, route)
	enemy.def.leash_radius = 3
	enemy.move.place(Vector2i(13, 10))
	enemy.threat.add(hero.id, 1.0)
	world.advance(0.1)
	assert_eq(enemy.home_tile, Vector2i(13, 10), "home is where it was pulled")
	enemy.move.place(Vector2i(13, 14)) # dragged past the leash
	world.advance(0.1)
	assert_eq(enemy.state, Enemy.State.EVADING)
	world.advance(5.0)
	assert_eq(enemy.state, Enemy.State.IDLE)
	world.advance(3.0)
	assert_ne(enemy.tile(), Vector2i(13, 10), "back on its route")


func test_charge_closes_the_gap_and_hits() -> void:
	var dash := AbilityEffect.new()
	dash.kind = AbilityEffect.Kind.DASH
	dash.base_amount = 3
	var charge := _ability(AbilityDef.Shape.FRONT, 4, 12.0)
	charge.min_range = 2
	charge.effects = [dash, charge.effects[0]]
	_setup(EnemyDef.Behavior.MELEE, charge, Vector2i(7, 8), Vector2i(7, 4), 5.0)
	var events := world.advance(1.0)
	assert_false(_casts(events).is_empty(), "charged from 4 tiles away")
	assert_true(events.any(func(e): return e.type == "dash" and e.source == enemy.id))
	assert_true(events.any(func(e): return e.type == "damage" and e.target == hero.id))
	world.advance(0.5)
	assert_eq(enemy.tile(), Vector2i(7, 5), "ends next to the target")
