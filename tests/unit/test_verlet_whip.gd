extends GutTest
## The Water Whip drawn in code (2026-11-25): a Verlet chain pinned to the hand,
## four colours, shown from the launch frame, gone after its recovery; the ability's
## numbers unchanged.

const HAND := Vector2(100, 50)
const TARGET := Vector2(160, 70)


func _fx() -> FxDef:
	return ContentDB.effects[&"water_whip"]


func _whip(seed := 7) -> VerletWhip:
	return VerletWhip.new(_fx().feel, _fx().hit_seconds(), seed)


func _run(w: VerletWhip, until: float, hand := HAND) -> void:
	var t := 0.0
	while t < until:
		t = minf(t + 1.0 / 60.0, until)
		w.advance(t, hand, TARGET)


func test_the_ability_is_unchanged() -> void:
	var a: AbilityDef = ContentDB.abilities[&"W02"]
	assert_eq(a.fx_cast, &"water_whip")
	assert_almost_eq(a.release_delay_seconds, 7.0 / 24.0, 0.001, "the hit on the snap, 0.29 s after the release")
	assert_eq(a.mana_cost, 6)
	assert_almost_eq(a.hitbox.reach if a.hitbox != null else float(a.max_range), 5.0, 0.001, "range 5")


func test_pinned_to_the_hand() -> void:
	var w := _whip()
	_run(w, 0.1)
	assert_eq(w.pos[0], HAND)
	_run(w, 0.2, HAND + Vector2(5, 3)) # the hero moves
	assert_eq(w.pos[0], HAND + Vector2(5, 3), "every frame")
	assert_eq(w.pos.size(), _fx().feel.point_count)


func test_the_same_for_everyone() -> void:
	var a := _whip(11)
	var b := _whip(11)
	_run(a, 0.25)
	# Another frame rate: the fixed steps give the same chain.
	var t := 0.0
	while t < 0.25:
		t = minf(t + 1.0 / 144.0, 0.25)
		b.advance(t, HAND, TARGET)
	for i in a.pos.size():
		assert_almost_eq(a.pos[i].distance_to(b.pos[i]), 0.0, 0.5, "point %d" % i)


func test_reaches_the_target_on_the_snap_and_cracks() -> void:
	var w := _whip()
	_run(w, w.hit_seconds + 0.01)
	assert_true(w.cracked)
	assert_lt(w.tip().distance_to(TARGET), 12.0, "the tip at the target as the hit lands")
	assert_gt(w.droplets().size(), 0, "the impact splashes droplets")


func test_gone_after_its_recovery() -> void:
	var w := _whip()
	var feel := _fx().feel
	_run(w, w.hit_seconds + feel.recovery_seconds - 0.02)
	assert_true(w.body_visible())
	assert_false(w.rasterize().is_empty())
	_run(w, w.hit_seconds + feel.recovery_seconds + 0.02)
	assert_false(w.body_visible())
	assert_true(w.rasterize().is_empty(), "nothing left of the whip")
	_run(w, _fx().duration() + 0.01)
	assert_false(w.alive(), "and the droplets have fallen")


func test_four_colours_whole_pixels() -> void:
	var w := _whip()
	_run(w, 0.2)
	var feel := _fx().feel
	var allowed := [feel.outline_color, feel.body_color, feel.highlight_color]
	var seen := {}
	for seg in w.rasterize():
		var part: Array = w.raster[seg]
		for i in part[0].size():
			var p: Vector2 = part[0][i]
			assert_eq(p, p.floor(), "whole art pixels")
			assert_true(part[1][i] in allowed)
			seen[part[1][i]] = true
	assert_true(seen.has(feel.outline_color), "a dark outline")
	assert_true(seen.has(feel.highlight_color), "a highlight")


func test_thick_at_the_hand_thin_at_the_tip() -> void:
	var w := _whip()
	_run(w, 0.1)
	assert_gt(w.width_at(0.0), w.width_at(1.0) * 2.0)


func test_anchors_from_the_data_file() -> void:
	var art: CreatureArtDef = ContentDB.heroes[&"adventurer"].art
	var doc = JSON.parse_string(FileAccess.get_file_as_string(art.anchors_path))
	var p: Array = doc.anchors.right_hand.water_whip.se[7]
	assert_eq(art.anchor("right_hand", "water_whip", "se", 7), Vector2(p[0], p[1]))
	assert_eq(art.anchor("right_hand", "water_whip", "se", 40), art.anchor("right_hand", "water_whip", "se", 8),
			"past the end: the last frame")
	assert_not_null(art.anchor("head", "water_whip", "se", 0), "head, feet and body centre have defaults")
	assert_not_null(art.anchor("body_centre", "idle", "n", 0))
	assert_null(art.anchor("left_hand", "water_whip", "se", 0), "not marked yet")
	assert_eq(art.launch_frame(&"W02", "sw"), 7, "launch on frame 8")
	for d in ["n", "ne", "nw"]:
		assert_true(art.hand_behind(&"W02", d), d)
	assert_false(art.hand_behind(&"W02", "s"))


func _event(seed := 3) -> Dictionary:
	return {"type": "fx", "fx": &"water_whip", "source": 1, "ability": &"W02", "from": Vector2(5, 5),
			"to": Vector2(8, 6), "at": 0.0, "seed": seed}


func _items(painter: FxPainter, hero: Hero, t: float, pose: Dictionary) -> Array:
	var art: CreatureArtDef = ContentDB.heroes[&"adventurer"].art
	return painter.items(t, [hero], [], ContentDB.abilities, ContentDB.effects, func(_a): return art,
			{"pose": func(_a): return pose}).filter(func(i): return i.has("verlet"))


func test_shown_from_the_launch_frame_and_behind_facing_away() -> void:
	var hero := Hero.new()
	hero.id = 1
	hero.move.place(Vector2i(5, 5))
	var painter := FxPainter.new()
	painter.on_events([_event()], ContentDB.effects)
	assert_eq(_items(painter, hero, 0.02, {"anim": "water_whip", "dir": "se", "frame": 6}).size(), 0,
			"nothing before the launch frame")
	var items := _items(painter, hero, 0.05, {"anim": "water_whip", "dir": "se", "frame": 7})
	assert_gt(items.size(), 1, "out from the launch frame")
	assert_false(items[0].behind)
	var away := FxPainter.new()
	away.on_events([_event()], ContentDB.effects)
	items = _items(away, hero, 0.05, {"anim": "water_whip", "dir": "ne", "frame": 7})
	assert_true(items.filter(func(i): return not i.has("extras")).all(func(i): return i.behind),
			"facing away: behind the hero")
	assert_eq(_items(away, hero, 2.0, {"anim": "idle", "dir": "ne", "frame": 0}).size(), 0, "gone after")
