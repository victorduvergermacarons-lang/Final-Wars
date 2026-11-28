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
	r.call_back(1.0) # the second press, early (water physics phase 4)
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
	r.call_back(1.0) # the second press, early (water physics phase 4)
	assert_gt(_until(r, "return"), 0)
	assert_gt(_until(r, "wrap"), 0, "back at the orbit")
	assert_eq(r.M(), settings.NMAX, "rebuilt from the pouch: whole before it re-enters")
	assert_true(r.attached().all(func(x): return x))
	assert_gt(float(r.readout.entry_px_s), 0.0)
	assert_gt(_until(r, "idle"), 0)


func test_the_water_waits_on_the_ground_for_the_second_press() -> void:
	var r := _rope()
	r.cast(Vector2(120, -80))
	assert_gt(_until(r, "ground"), 0, "regrouped on the ground")
	for i in 120:
		r.step()
	assert_eq(r.st, "ground", "still waiting")
	var m := r.M()
	var soaked := r.lost.size()
	r.call_back(0.5)
	assert_eq(r.st, "rise", "the press brings it back")
	assert_eq(r.M(), roundi(m * 0.5), "half of it")
	assert_eq(r.lost.size(), soaked + m - roundi(m * 0.5), "the tail soaks in")
	r.cast(Vector2(80, 0))
	r.call_back(0.0)
	assert_gt(_until(r, "idle"), 0, "none of it: it soaks in where it landed")
	assert_lte(r.M(), 1, "the rope grows back from the source")


func test_recast_during_wrap() -> void:
	var r := _rope()
	r.cast(Vector2(100, 0))
	r.call_back(1.0) # the second press, early (water physics phase 4)
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


# --- Healing Touch (water physics phase 4) ------------------------------------------

func test_heal_reaches_the_top_at_the_heal_time() -> void:
	var r := _rope()
	r.heal(Vector2(60, 20), false)
	assert_eq(r.st, "heal")
	var top: Vector3 = r.hpath.pts[r.hpath.pts.size() - 1]
	assert_almost_eq(top.z, settings.HERO_H + settings.TOP_LIFT, 0.01, "above the head")
	for i in settings.HEAL_T - 1:
		r.step()
	assert_true(r.mists.is_empty(), "not yet at the top")
	r.step()
	r.step()
	assert_gt(r.mists.size(), 0, "the lead turned to mist at the top, on time")


func test_the_heal_s_unused_share_goes_home_off_the_tail() -> void:
	var r := _rope()
	r.heal(Vector2(60, 20), false)
	for i in settings.HEAL_T:
		r.step()
	var n := r.M()
	r.heal_back(0.5)
	assert_eq(r.st, "return", "the tail heads home")
	assert_eq(r.M(), roundi(0.5 * settings.NMAX), "half the rope")
	assert_eq(r.heal_tail.size(), n - r.M(), "the front climbs on")
	for i in 400:
		r.step()
	assert_true(r.heal_tail.is_empty(), "all of the front turned to mist")


func test_a_self_heal_unwinds_into_the_orbit() -> void:
	var r := _rope()
	r.heal(Vector2.ZERO, true)
	for i in settings.HEAL_T:
		r.step()
	r.heal_back(1.0)
	assert_eq(r.st, "idle", "straight back into the orbit")
	assert_gt(r.M(), 0)


# --- Water Shield (water physics phase 4) -------------------------------------------

func _shield(target := Vector2(50, 10), is_self := false) -> WaterShieldRope:
	var r := _rope()
	var sh := WaterShieldRope.new(settings, 3)
	var pts: Array[WaterRope.Pt] = r.R.duplicate()
	sh.cast_shield(pts, target, is_self, r.phase, r.w)
	return sh


func test_the_shield_goes_up_on_time_and_stretches() -> void:
	var sh := _shield()
	for i in settings.SH_T - 1:
		sh.step()
	assert_false(sh.shield_up)
	sh.step()
	assert_true(sh.shield_up, "up at SH_T frames")
	var r0 := sh.M()
	for i in settings.GROW_T:
		sh.step()
	assert_gt(sh.M(), r0, "stretched (points fed in at the tail)")
	assert_almost_eq(sh.wscale, settings.WIDTH_MULT, 0.01, "thinner")
	# Every point on the bubble sits on its sphere.
	var C: Vector3 = sh.sph.C
	for j in range(1, sh.M()):
		assert_almost_eq(sh.R[j].p.distance_to(C), float(sh.sph.r), 2.0) # the links pull a little, as in the demo


func test_the_shield_rope_follows_the_shield_left() -> void:
	var sh := _shield()
	for i in settings.SH_T + settings.GROW_T:
		sh.step()
	var full := sh.M()
	sh.set_left(0.5)
	assert_gt(sh.drops.size(), 0, "the hit splashes")
	for i in 60:
		sh.step()
	assert_almost_eq(float(sh.M()), full * 0.5, 2.0, "half as long")


func test_broken_it_bursts_falls_and_soaks_in() -> void:
	var sh := _shield()
	for i in settings.SH_T + 10:
		sh.step()
	sh.pop()
	assert_eq(sh.st, "shield_fall")
	for i in settings.POP_FALL + 2:
		sh.step()
	assert_eq(sh.M(), 0, "none of it comes home")
	assert_gt(sh.lost.size(), 0, "soaked in")


func test_run_out_it_comes_home_with_what_is_left() -> void:
	var sh := _shield()
	for i in settings.SH_T + settings.GROW_T:
		sh.step()
	sh.unwind(0.5)
	assert_eq(sh.st, "return")
	var frames := 0
	while sh.st != "wrap" and sh.st != "idle" and frames < 1500:
		sh.step()
		frames += 1
	assert_true(sh.st == "wrap" or sh.st == "idle", "back at the orbit")
	assert_eq(sh.M(), roundi(settings.NMAX * 0.5), "12 points")


# --- Leeching Tide (water physics phase 4) ------------------------------------------

func test_the_hoop_reaches_out_latches_drains_and_closes_again() -> void:
	var r := _rope()
	r.set_stance(2)
	r.set_count(33)
	for i in 400:
		r.step()
	assert_true(r.wrap, "a closed hoop first")
	r.leech(Vector2(60, -20))
	assert_eq(r.st, "reach")
	assert_false(r.wrap, "the hoop opens")
	for i in settings.REACH_T:
		r.step()
	assert_eq(r.st, "leech", "latched after REACH_T frames")
	for i in 120:
		r.step()
	assert_true(r.R.any(func(p): return p.dark > 0.5), "dark water drawn out of the target")
	r.end_leech()
	var frames := 0
	while r.st != "idle" and frames < 2000:
		r.step()
		frames += 1
	assert_eq(r.st, "idle", "the rest flowed home")
	for i in 300:
		r.step()
	assert_true(r.wrap, "the hoop closes again")


func test_the_code_drawn_shard_points_ahead() -> void:
	# The demo's shardShape: 9 px long, 1.5 half-wide, pointed at the front.
	var set := WaterRopes.shard_pixels(Vector2(0.5, 0.5), Vector2.RIGHT, 9.0, 1.5)
	var xs := set.keys().map(func(k): return k.x)
	assert_between(xs.max() - xs.min() + 1, 8, 10, "about 9 px long")
	var front := set.keys().filter(func(k): return k.x == xs.max()).size()
	var back_mid := set.keys().filter(func(k): return k.x == -2).size()
	assert_lt(front, back_mid, "narrow at the point, fuller behind")
