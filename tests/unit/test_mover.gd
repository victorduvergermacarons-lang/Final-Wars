extends GutTest
## Free movement (Mover, WorldSim): acceleration and stopping, 8 directions with
## the diagonal not faster, sliding along walls, climbing within Jump, cliffs,
## drops and falls under gravity with fall damage, slows / Haste / roots, units
## pushing each other, leaving through map edges, and facing.

var rules: CombatRules
var world: WorldSim
var hero: Hero


## 12×12 open ground at height 0, with: a wall column at x = 8 (rows 0–3), a step
## of 1 at (3, 8), a 2-level block at (5, 8), and a 6-level plateau x 9–11, y 8–11.
func _zone() -> ZoneDef:
	var z := ZoneDef.new()
	z.id = &"field"
	var h: PackedStringArray = []
	var w: PackedStringArray = []
	for y in 12:
		var hr := ""
		var wr := ""
		for x in 12:
			var height := 0
			if x == 3 and y == 8:
				height = 1
			elif x == 5 and y == 8:
				height = 2
			elif x >= 9 and y >= 8:
				height = 6
			hr += str(height)
			wr += "#" if x == 8 and y <= 3 else "."
		h.append(hr)
		w.append(wr)
	z.height_rows = h
	z.walk_rows = w
	z.hero_spawns = [Vector2i(1, 1)] as Array[Vector2i]
	return z


func before_each() -> void:
	rules = CombatRules.new()
	world = WorldSim.new(_zone(), rules, 3)
	hero = world.add_hero(ContentDB.heroes[&"adventurer"])
	hero.move.place(Vector2i(2, 2))
	world.step()


func _move(dir: Vector2i, seconds: float) -> void:
	world.submit(hero.id, {"type": "move", "dir": dir, "face": 0.0})
	world.advance(seconds)


func _speed() -> float:
	return hero.move.vel.length()


func test_w_walks_up_the_screen() -> void:
	assert_eq(Mover.screen_to_grid(Vector2i(0, -1)), Vector2(-1, -1).normalized(), "W: grid up-left")
	assert_eq(Mover.screen_to_grid(Vector2i(1, 0)), Vector2(1, -1).normalized(), "D: grid up-right")
	# Screen down-right is 45° on screen, which on the 2:1 isometric grid is not
	# grid +x (that is 26.6° on screen) but close to it.
	var sd := Mover.screen_to_grid(Vector2i(1, 1))
	assert_almost_eq(sd.length(), 1.0, 0.0001)
	assert_almost_eq(rad_to_deg(sd.angle()), 18.43, 0.01, "S+D: 45° down-right on screen")
	assert_eq(Mover.screen_to_grid(Vector2i.ZERO), Vector2.ZERO)


func test_reaches_full_speed_in_about_a_tenth_and_stops_in_under_a_tenth() -> void:
	var full := rules.movement.walk_speed
	assert_eq(full, 3.0, "3 tiles per second, in and out of combat")
	world.submit(hero.id, {"type": "move", "dir": Vector2i(1, 1), "face": 0.0})
	world.step()
	assert_between(_speed(), 0.3, full - 0.1, "accelerating, not instant")
	world.step()
	assert_almost_eq(_speed(), full, 0.01, "full speed after 0.1 s")
	_move(Vector2i.ZERO, 0.0)
	world.step()
	assert_gt(_speed(), 0.0, "decelerating")
	world.step()
	assert_eq(_speed(), 0.0, "stopped within 0.1 s")


func test_diagonals_are_not_faster() -> void:
	var start := hero.move.pos
	_move(Vector2i(1, 1), 1.0)
	var straight := hero.move.pos.distance_to(start)
	hero.move.place(Vector2i(2, 5))
	world.step()
	start = hero.move.pos
	_move(Vector2i(1, 0), 1.0) # screen right: a grid diagonal
	var diagonal := hero.move.pos.distance_to(start)
	assert_almost_eq(diagonal, straight, 0.05, "same distance per second either way")
	assert_between(straight, 2.6, 3.0, "about 3 tiles in a second, less the acceleration")


func test_combat_speed_is_the_same_by_default() -> void:
	hero.combat_until = 999.0
	assert_eq(Mover.speed_of(hero, rules, world.now), rules.movement.walk_speed)
	rules.movement.combat_speed_factor = 0.8
	assert_almost_eq(Mover.speed_of(hero, rules, world.now), 2.4, 0.001, "tunable in data")
	rules.movement.combat_speed_factor = 1.0


func test_slides_along_a_wall() -> void:
	hero.move.place(Vector2(7.2, 2.0))
	world.step()
	# Screen right + down = grid +x: straight into the wall at x = 8; plus some grid +y.
	world.submit(hero.id, {"type": "move", "dir": Vector2i(1, 1), "face": 0.0})
	world.advance(0.5)
	assert_lte(hero.move.pos.x, 7.5 - hero.move.radius + 0.01, "stopped by the wall")
	world.submit(hero.id, {"type": "move", "dir": Vector2i(0, 1), "face": 0.0}) # grid (+x, +y)
	world.advance(0.5)
	assert_gt(hero.move.pos.y, 2.5, "slides along it")
	assert_lte(hero.move.pos.x, 7.5 - hero.move.radius + 0.01)


func test_climbs_a_step_within_jump_but_not_a_cliff() -> void:
	hero.move.place(Vector2i(3, 6))
	world.step()
	hero.walk_target = null
	world.submit(hero.id, {"type": "step", "to": Vector2i(3, 8)})
	world.advance(1.0)
	assert_eq(hero.tile(), Vector2i(3, 8), "up a 1-level step")
	assert_eq(hero.move.ground_h, 1)
	hero.move.place(Vector2i(10, 6))
	world.step()
	world.submit(hero.id, {"type": "step", "to": Vector2i(10, 7)})
	world.advance(0.6)
	world.submit(hero.id, {"type": "move", "dir": Vector2i(-1, 1), "face": 0.0}) # grid +y, at the plateau
	world.advance(0.6)
	assert_lt(hero.move.pos.y, 7.5, "the 6-level cliff face blocks")


func test_a_two_level_drop_is_a_fall_under_gravity() -> void:
	hero.move.place(Vector2i(5, 8))
	world.step()
	assert_eq(hero.move.ground_h, 2)
	world.submit(hero.id, {"type": "move", "dir": Vector2i(-1, 1), "face": 0.0}) # grid +y
	var zs: Array[float] = []
	var fell := false
	for i in 20:
		for e in world.step():
			fell = fell or e.type == "fall"
		if hero.move.falling():
			zs.append(hero.move.z)
	assert_true(fell, "it fell")
	assert_gt(zs.size(), 1)
	# Gravity: each tick it drops further than the tick before.
	assert_gt(zs[0] - zs[1], 0.0)
	if zs.size() > 2:
		assert_gt(zs[1] - zs[2], zs[0] - zs[1], "accelerating down")
	assert_false(hero.move.falling(), "landed")
	assert_eq(hero.hp, hero.stats.hp, "2 levels: no damage")


func test_falls_over_three_levels_hurt() -> void:
	var md := rules.movement
	assert_eq(Mover.fall_damage(3, 100.0, md), 0.0, "3 levels: fine")
	assert_eq(Mover.fall_damage(4, 100.0, md), 10.0, "each level beyond 3: 10%")
	assert_eq(Mover.fall_damage(6, 100.0, md), 30.0)
	assert_eq(Mover.fall_damage(20, 100.0, md), 60.0, "capped at 60%")
	# Off the 6-level plateau.
	hero.move.place(Vector2i(9, 9))
	world.step()
	assert_eq(hero.move.ground_h, 6)
	var hp := hero.hp
	world.submit(hero.id, {"type": "move", "dir": Vector2i(-1, -1), "face": 0.0}) # grid -x
	var events := world.advance(1.0)
	assert_true(events.any(func(e): return e.type == "landed" and e.levels == 6))
	assert_true(events.any(func(e): return e.type == "damage" and e.ability == &"fall"))
	assert_almost_eq(hero.hp, hp - roundf(hero.stats.hp * 0.3), 1.0, "6 levels: 30% of max HP")


func test_a_fall_cannot_kill_unless_set() -> void:
	hero.hp = 5.0
	hero.move.place(Vector2i(9, 9))
	world.step()
	world.submit(hero.id, {"type": "move", "dir": Vector2i(-1, -1), "face": 0.0})
	var landed := false
	for i in 30:
		if world.step().any(func(e): return e.type == "damage" and e.ability == &"fall"):
			landed = true
			break
	assert_true(landed)
	assert_true(hero.alive)
	assert_lt(hero.hp, 1.2, "left at 1 HP (plus a tick of regen)")


func test_no_steering_while_falling() -> void:
	hero.move.place(Vector2(9.6, 9))
	world.step()
	world.submit(hero.id, {"type": "move", "dir": Vector2i(-1, -1), "face": 0.0}) # grid -x
	while not hero.move.falling():
		world.step()
	var x := hero.move.pos.x
	world.submit(hero.id, {"type": "move", "dir": Vector2i(1, 1), "face": 0.0}) # try to turn back
	world.step()
	assert_lt(hero.move.pos.x, x, "still carried off the ledge")


func test_slows_haste_and_roots() -> void:
	var slow := BuffDef.new()
	slow.id = &"slow"
	slow.step_cooldown_multiplier = 1.5
	hero.buffs.apply(slow, world.now)
	assert_almost_eq(Mover.speed_of(hero, rules, world.now), 2.0, 0.001, "×1.5 slow: 2 tiles/s")
	hero.buffs.clear()
	var root := BuffDef.new()
	root.id = &"root"
	root.roots = true
	hero.buffs.apply(root, world.now)
	_move(Vector2i(1, 1), 0.5)
	assert_eq(hero.tile(), Vector2i(2, 2), "rooted")


func test_units_push_apart_and_never_overlap() -> void:
	var other := world.add_hero(ContentDB.heroes[&"adventurer"])
	other.move.place(Vector2(3.0, 2.0))
	world.step()
	_move(Vector2i(1, 1), 1.0) # into the other hero
	var d := hero.move.pos.distance_to(other.move.pos)
	assert_gte(d, hero.move.radius + other.move.radius - 0.02, "no overlap")
	assert_gt(other.move.pos.x, 3.0, "pushed along")


func test_heroes_slide_around_enemies() -> void:
	var wolf := world.add_enemy(ContentDB.enemies[&"wolf"], Vector2i(4, 2))
	wolf.move.place(Vector2i(4, 2))
	world.step()
	_move(Vector2i(1, 1), 1.0)
	assert_gte(hero.move.pos.distance_to(wolf.move.pos), hero.move.radius + wolf.move.radius - 0.02)
	assert_eq(wolf.tile(), Vector2i(4, 2), "an enemy stepping tile to tile isn't shoved")


func test_faces_where_it_walks_and_the_mouse_in_combat() -> void:
	_move(Vector2i(1, 1), 0.3) # screen down-right
	assert_almost_eq(hero.facing_angle, Mover.screen_to_grid(Vector2i(1, 1)).angle(), 0.05, "faces where it walks")
	assert_eq(hero.facing, Vector2i.RIGHT, "the sprite's nearest direction")
	hero.combat_until = 999.0
	world.submit(hero.id, {"type": "move", "dir": Vector2i(1, 1), "face": PI / 2.0})
	world.step()
	assert_almost_eq(hero.facing_angle, PI / 2.0, 0.001, "in combat: the mouse")
	assert_eq(hero.facing, Vector2i.DOWN)


func test_moving_cancels_a_cast_bar() -> void:
	hero.casting = {"ability": AbilityDef.new(), "kind": "cast", "start": 0.0, "end": 99.0, "target": -1}
	_move(Vector2i(1, 1), 0.1)
	assert_true(hero.casting.is_empty())


func test_positions_interpolate_between_ticks() -> void:
	_move(Vector2i(1, 1), 0.5)
	var m := hero.move
	var mid := m.position_at(m.time + rules.tick_seconds * 0.5)
	assert_almost_eq(mid.x, (m.prev_pos.x + m.pos.x) / 2.0, 0.001, "half way between the last two ticks")
