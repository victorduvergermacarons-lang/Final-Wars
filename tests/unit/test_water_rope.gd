extends GutTest
## The Water stance 1 rope and Water Whip, ported from
## docs/reference/water_whip_reference.html (2026-11-26).

var settings: WaterRopeSettings


func before_each() -> void:
	settings = load("res://content/effects/water_rope_settings.tres")


func _rope() -> WaterRope:
	var r := WaterRope.new(settings, 5)
	r.source = Vector3(0, 0, settings.HIP_Z)
	r.fill_now()
	return r


func _until(r: WaterRope, state: String, max_frames := 2000) -> int:
	for f in max_frames:
		if r.st == state:
			return f
		r.step()
	return -1


func test_hit_lands_after_30_frames_near_and_far() -> void:
	for d in [25.0, 60.0, 140.0]:
		var r := _rope()
		for i in 60:
			r.step() # settle on the orbit
		r.cast(Vector2(d, -d * 0.3))
		var frames := 0
		while r.st != "pour" and frames < 100:
			r.step()
			frames += 1
		assert_eq(frames, settings.HIT, "hit at %d px after exactly 0.5 s" % d)
		assert_almost_eq(float(r.readout.hit_s), 0.5, 0.001)


func test_near_throws_pull_back_and_spin() -> void:
	var r := _rope()
	r.cast(Vector2(20, 5))
	assert_gt(r.Bk, 4.0, "a pull-back over the shoulder")
	assert_eq(r.st, "spin", "spare time spent spinning")
	var far := _rope()
	far.cast(Vector2(140, -60))
	assert_eq(far.st, "fly")


func test_pours_then_breaks_at_point_12() -> void:
	var r := _rope()
	r.cast(Vector2(90, -40))
	_until(r, "pour")
	assert_true(r.poured[0], "the front breaks off at the hit")
	var pouring := 0
	while r.st == "pour" and pouring < 200:
		assert_false(r.poured[settings.POUR_POINTS - 1] and r.st == "pour", "breaks the moment point 12 arrives")
		r.step()
		pouring += 1
	assert_eq(r.st, "fall")
	assert_true(r.conn.all(func(c): return not c), "every link broken")
	assert_gt(r.drops.size(), 0, "splashes")


func test_regroup_keeps_at_least_8() -> void:
	var r := _rope()
	r.cast(Vector2(120, -80))
	_until(r, "rise")
	assert_gte(r.M(), settings.MIN_KEEP)
	assert_eq(r.M() + r.lost.size(), settings.NMAX, "the rest soaked in")
	var far := 0.0
	for p in r.R:
		far = maxf(far, Vector2(p.p.x, p.p.y).length())
	assert_almost_eq(Vector2(r.R[0].p.x, r.R[0].p.y).length(), far, 0.001, "the farthest is the new front")


func test_returns_whole_wraps_and_idles() -> void:
	var r := _rope()
	r.cast(Vector2(120, -80))
	assert_gt(_until(r, "return"), 0)
	assert_gt(_until(r, "wrap"), 0, "back at the orbit")
	assert_eq(r.M(), settings.NMAX, "rebuilt from the pouch: whole before it re-enters")
	assert_true(r.attached().all(func(x): return x))
	assert_gt(float(r.readout.entry_px_s), 0.0)
	assert_gt(_until(r, "idle"), 0)


func test_recast_during_wrap() -> void:
	var r := _rope()
	r.cast(Vector2(100, 0))
	_until(r, "wrap")
	assert_true(r.can_cast())
	r.cast(Vector2(-80, 30))
	assert_true(r.st == "fly" or r.st == "spin")


func test_cast_while_out_snaps_back_and_throws() -> void:
	var r := _rope()
	r.cast(Vector2(100, 0))
	_until(r, "fall")
	r.cast(Vector2(-60, 20))
	assert_true(r.st == "fly" or r.st == "spin")
	var frames := 0
	while r.st != "pour" and frames < 100:
		r.step()
		frames += 1
	assert_eq(frames, settings.HIT, "still 0.5 s")


func test_forms_from_the_source_and_refills_from_the_hips() -> void:
	var r := WaterRope.new(settings, 1)
	r.source = Vector3(0, 0, settings.HIP_Z)
	assert_true(r.is_empty())
	for i in settings.NMAX * settings.FORM_EVERY + 5:
		r.step()
	assert_eq(r.M(), settings.NMAX, "the orbit forms point by point")
	r.fill_now(10)
	r.forming = false
	r.set_count(settings.NMAX) # the host's stance water grew back
	for i in settings.REFILL_EVERY * 3 + 1:
		r.step()
	assert_eq(r.M(), 13, "one point every REFILL_EVERY frames while idle")


func test_drain_empties_it() -> void:
	var r := _rope()
	r.drain()
	for i in 400:
		r.step()
	assert_true(r.done())


func test_the_world_stays_put_while_it_flies() -> void:
	var r := _rope()
	r.cast(Vector2(120, 0))
	_until(r, "fly")
	var aim := r.aim
	r.move_hero(Vector2(10, 0))
	assert_eq(r.aim, aim - Vector3(10, 0, 0), "the target stays where it is in the world")
	var frames := 0
	while r.st != "pour" and frames < 100:
		r.step()
		frames += 1
	assert_almost_eq(r.R[0].p.distance_to(r.aim), 0.0, 0.01)


func test_return_speed_scales_with_length() -> void:
	var r := _rope()
	assert_almost_eq(r.dist_scale(settings.DIST_REF), 1.0, 0.001)
	assert_almost_eq(r.dist_scale(settings.DIST_REF * 0.5), settings.HALF_TRIP, 0.001, "half length at 40%")
	assert_almost_eq(WaterRope.prof(1.0), 1.0, 0.001)
	assert_almost_eq((WaterRope.prof(1.0) - WaterRope.prof(0.999)) / 0.001, 2.07, 0.02, "peak ≈ 2.07 × average")


func _hero_with_rope() -> Hero:
	var h := Hero.new()
	h.id = 7
	h.move.place(Vector2i(10, 10))
	h.stance_tree = "Water"
	h.stance = 1
	h.stance_water = 24
	return h


func test_each_hero_gets_its_rope_and_the_whip_event_throws_it() -> void:
	var ropes := WaterRopes.new(settings)
	var h := _hero_with_rope()
	var on := func(_x): return true
	ropes.advance(0.5, 0.0, [h], null, null, on)
	var r := ropes.rope_of(h.id)
	assert_not_null(r, "a rope while the host says it has one")
	assert_gt(r.M(), 0, "forming from the hips")
	ropes.on_events([{"type": "fx", "fx": &"water_whip", "source": h.id, "to": Vector2(13, 10), "at": 1.0}],
			ContentDB.effects)
	ropes.advance(0.1, 0.9, [h], null, null, on)
	assert_eq(r.st, "idle", "not before its host time")
	ropes.advance(0.1, 1.0, [h], null, null, on)
	assert_true(r.st == "fly" or r.st == "spin", "thrown at its host time")
	var items := ropes.items(func(_h): return Vector2.ZERO)
	assert_true(items.any(func(i): return i.has("stamps")), "slices to draw")
	h.stance_water = 0
	for i in 30:
		ropes.advance(0.2, 1.0 + i * 0.2, [h], null, null, on)
	assert_null(ropes.rope_of(h.id), "drained away once the stance is left")


func test_off_screen_heroes_are_skipped() -> void:
	var ropes := WaterRopes.new(settings)
	var h := _hero_with_rope()
	ropes.advance(0.5, 0.0, [h], null, null, func(_x): return false)
	var r := ropes.rope_of(h.id)
	var before := r.fr
	ropes.advance(1.0, 1.0, [h], null, null, func(_x): return false)
	assert_eq(r.fr, before, "no steps off screen")
	assert_true(ropes.items(func(_h): return Vector2.ZERO).is_empty())
	ropes.advance(0.1, 1.1, [h], null, null, func(_x): return true)
	assert_eq(r.M(), settings.NMAX, "back on its orbit when it comes back")
