extends GutTest
## Fire physics, the CPU side of the effects (the GPU passes are checked by the bench).


func test_growth_is_x_over_180_plus_x() -> void:
	assert_almost_eq(FireLookDef.growth(0.0), 0.0, 1e-6)
	assert_almost_eq(FireLookDef.growth(180.0), 0.5, 1e-6)
	assert_almost_eq(FireLookDef.growth(1000.0), 1000.0 / 1180.0, 1e-6)


func test_settings_interpolate_from_mastery_0_to_the_limit() -> void:
	var look: FireLookDef = load("res://content/effects/fire/F12.tres")
	assert_eq(look.kind, "stream")
	var a := look.settings(0.0)
	var b := look.settings(180.0)
	assert_almost_eq(float(a.temp), 0.7, 1e-6)
	assert_almost_eq(float(b.temp), 0.8, 1e-6, "halfway at 180: 0.7 + (0.9 - 0.7) / 2")
	assert_almost_eq(float(b.brk), 0.75, 1e-6, "BASE values come through")


func test_every_fire_ability_has_a_look() -> void:
	for id in ["F01", "F02", "F03", "F04", "F06", "F07", "F09", "F10", "F11", "F12", "F14", "F15", "F16", "F18", "F23"]:
		var look: FireLookDef = load("res://content/effects/fire/%s.tres" % id)
		assert_not_null(look, id)
		assert_ne(look.kind, "", id)
		assert_false(look.s0.is_empty(), id)


func test_window_corner_is_a_tile_corner_and_points_round_trip() -> void:
	var e := FireEffect.new()
	e.origin = FireEffect.place_origin(Vector2(10.3, 7.8), Vector2(1, -1))
	var hero := e.to_local(Vector2(10.3, 7.8))
	assert_true(hero.x > 8 and hero.x < 40 and hero.y > 88 and hero.y < 120, "the caster sits near the corner behind the aim: %s" % hero)
	assert_almost_eq(e.to_world(hero).x, 10.3, 1e-4)
	assert_almost_eq(e.to_world(Vector2.ZERO).x, float(e.origin.x) - 0.5, 1e-6, "cell (0, 0) is a tile's corner")


func test_a_fire_drop_falls_lands_and_licks_the_floor() -> void:
	var sim := FireSim.new()
	var e := FireEffect.new()
	e.look = load("res://content/effects/fire/F15.tres")
	e.p = e.look.settings(0.0)
	e.slot = sim.alloc()
	e.drop(40, 40, 3.0, 0.0, 0.0, -1.0, 0.0, 0.0)
	e.part(50, 50, 5.0, 0.1, 0.0, 0.0, 10.0, 3)
	for i in 3:
		e.step_parts(sim)
	assert_eq(e.parts.size(), 1, "the drop landed and is gone; the ember lives on")
	assert_eq(sim._sources[e.slot].size(), 1, "landing licked the floor")
	assert_eq(int(sim._sources[e.slot][0][0]), 3, "a single flame cell")
	for i in 10:
		e.step_parts(sim)
	assert_eq(e.parts.size(), 0, "the ember ran out")
	sim.free()
