extends GutTest
## Code-drawn effects (stance rework phase 4, 2026-11-23): the whip curve, streams
## stopping at the first unit or a blocker, front rays stopping where the hitbox
## stops (a pillar in a cone leaves a gap), burning ground auto-tiled by
## neighbours, and clients rebuilding the same shapes from the host's data.

var world: World
var sim: WorldSim
var hero: Hero


func before_each() -> void:
	ContentDB.rules.timing_bars_enabled = false
	world = World.new(ContentDB.zones.values(), ContentDB.rules, 5, &"town", ContentDB.quests)
	hero = world.add_saved_hero(CharacterData.new_character("Rook", ContentDB.heroes[&"adventurer"]), ContentDB)
	sim = world.zone_of(hero.id)
	world.step()


func after_each() -> void:
	ContentDB.rules.timing_bars_enabled = true


func _whip() -> FxDef:
	return ContentDB.effects[&"water_whip_ribbon"]


## How far the path strays from the straight line between its ends (tiles).
static func _slack(pts: PackedVector3Array) -> float:
	var a := Vector2(pts[0].x, pts[0].y)
	var b := Vector2(pts[pts.size() - 1].x, pts[pts.size() - 1].y)
	var dir := (b - a).normalized()
	var most := 0.0
	for p in pts:
		most = maxf(most, absf((Vector2(p.x, p.y) - a).cross(dir)))
	return most


func test_whip_starts_at_the_hand_and_ends_at_the_target() -> void:
	var fx := _whip()
	var snap := float(fx.snap_frame) / fx.fps
	var from := Vector2(10, 10)
	var to := Vector2(13, 11)
	var pts := RibbonPath.points(fx, from, to, snap, 7, 5.0, 2.0)
	assert_almost_eq(Vector2(pts[0].x, pts[0].y).distance_to(from), 0.0, 0.001, "starts at the hand")
	assert_almost_eq(pts[0].z, 2.0, 0.001, "at the hand's height")
	var last := pts[pts.size() - 1]
	assert_almost_eq(Vector2(last.x, last.y).distance_to(to), 0.0, 0.001, "reaches the target on the snap")


func test_whip_curls_more_when_the_target_is_close() -> void:
	var fx := _whip()
	var snap := float(fx.snap_frame) / fx.fps
	var from := Vector2(10, 10)
	var near := _slack(RibbonPath.points(fx, from, from + Vector2(1.5, 0), snap, 3, 5.0, 1.0)) / 1.5
	var far := _slack(RibbonPath.points(fx, from, from + Vector2(4.8, 0), snap, 3, 5.0, 1.0)) / 4.8
	assert_gt(near, far * 3.0, "a deep curl close up, nearly straight at full range")


func test_whip_shape_is_the_same_for_the_same_inputs() -> void:
	var fx := _whip()
	var a := RibbonPath.points(fx, Vector2(3, 4), Vector2(6, 2), 0.2, 41, 5.0, 1.5)
	var b := RibbonPath.points(fx, Vector2(3, 4), Vector2(6, 2), 0.2, 41, 5.0, 1.5)
	assert_eq(a, b)
	var other := RibbonPath.points(fx, Vector2(3, 4), Vector2(6, 2), 0.2, 42, 5.0, 1.5)
	assert_ne(a, other, "another seed bends it the other way")


func test_whip_reaches_out_snaps_and_pulls_back() -> void:
	var fx := _whip()
	assert_almost_eq(fx.reach_at(0.0), 0.0, 0.001)
	assert_almost_eq(fx.reach_at(float(fx.snap_frame) / fx.fps), 1.0, 0.001)
	assert_lt(fx.reach_at(float(fx.snap_frame + fx.retract_frames / 2) / fx.fps), 1.0)
	assert_eq(ContentDB.abilities[&"W02"].release_delay_seconds, float(fx.hit_frame) / fx.fps, "the hit on the snap")


func test_lightning_rejags_from_the_seed() -> void:
	var fx: FxDef = ContentDB.effects[&"lightning_bolt"]
	var a := RibbonPath.points(fx, Vector2(0, 0), Vector2(4, 0), 0.01, 5, 6.0, 1.0)
	assert_eq(a, RibbonPath.points(fx, Vector2(0, 0), Vector2(4, 0), 0.02, 5, 6.0, 1.0), "same jags within 0.05 s")
	assert_ne(a, RibbonPath.points(fx, Vector2(0, 0), Vector2(4, 0), 0.07, 5, 6.0, 1.0), "re-jagged after")


## A flat, open patch of ground (made so), returning a tile near its west end.
func _open_ground() -> Vector2i:
	var at := Vector2i(6, 6)
	for x in range(at.x - 2, at.x + 9):
		for y in range(at.y - 4, at.y + 5):
			sim.grid.set_tile(Vector2i(x, y), 0, true)
			sim.grid.set_blocks_sight(Vector2i(x, y), false)
	for a in sim.enemies():
		if a.move.pos.distance_to(Vector2(at)) < 10.0:
			sim.remove_enemy(a.id)
	return at


func test_stream_stops_at_the_first_unit_or_a_blocker() -> void:
	var at := _open_ground()
	assert_ne(at, Vector2i(-1, -1), "open ground found")
	hero.move.place(at)
	var stream: AbilityDef = ContentDB.abilities[&"F12"]
	var data := sim.shape_fx_data(hero, stream, &"fire_stream", null, Vector2(at) + Vector2(5, 0))
	assert_gt(Vector2(data.to).distance_to(hero.move.pos), 3.0, "open ground: out to its range")
	var wolf := sim.add_enemy(ContentDB.enemies[&"wolf"], at + Vector2i(3, 0))
	data = sim.shape_fx_data(hero, stream, &"fire_stream", null, Vector2(at) + Vector2(5, 0))
	assert_almost_eq(Vector2(data.to).distance_to(wolf.move.pos), 0.0, 0.05, "stops at the first unit")
	sim.remove_enemy(wolf.id)
	sim.grid.set_tile(at + Vector2i(2, 0), sim.grid.height_at(at) + 4, false)
	data = sim.shape_fx_data(hero, stream, &"fire_stream", null, Vector2(at) + Vector2(5, 0))
	assert_lt(Vector2(data.to).distance_to(hero.move.pos), 2.0, "stops at the wall")


func test_front_rays_stop_where_the_hitbox_stops() -> void:
	var at := _open_ground()
	hero.move.place(at)
	var breath: AbilityDef = ContentDB.abilities[&"F14"]
	var data := sim.shape_fx_data(hero, breath, &"breath_of_fire", null, Vector2(at) + Vector2(4, 0))
	var rays: Array = data.rays
	assert_gt(rays.size(), 5, "fanned across the cone")
	for r in rays:
		assert_almost_eq(float(r[4]), float(r[5]), 0.001, "open ground: every ray runs its length")
	# A pillar straight ahead: the rays through it stop there, the ones beside go on.
	sim.grid.set_tile(at + Vector2i(2, 0), sim.grid.height_at(at) + 4, false)
	rays = sim.shape_fx_data(hero, breath, &"breath_of_fire", null, Vector2(at) + Vector2(4, 0)).rays
	var stopped := rays.filter(func(r): return float(r[4]) < float(r[5]) - 0.05)
	var through := rays.filter(func(r): return float(r[4]) >= float(r[5]) - 0.05)
	assert_gt(stopped.size(), 0, "the pillar stops some")
	assert_gt(through.size(), 0, "a gap, not a wall: the others go on")
	for r in stopped:
		assert_lt(float(r[4]), 2.0, "stopped at the pillar")


func test_burning_ground_fades_toward_open_sides() -> void:
	var painter := FxPainter.new()
	var fx: FxDef = ContentDB.effects[&"burning_ground"]
	# An L: (0,0) (1,0) (2,0) (0,1).
	var tiles := [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1)]
	var items := painter.burning_items(fx, tiles, 0.0, ContentDB.effects)
	assert_eq(items.size(), 4, "flames on every burning tile")
	var by_tile := {}
	for i in items:
		by_tile[MoveState.tile_of(i.pos)] = i.fade
	# Sides in order: -x, +x, -y, +y.
	assert_eq(Array(by_tile[Vector2i(1, 0)]), [1.0, 1.0, FxPainter.BURN_EDGE_ALPHA, FxPainter.BURN_EDGE_ALPHA],
			"the middle of the bar: burning left and right, open above and below")
	assert_eq(Array(by_tile[Vector2i(0, 0)]), [FxPainter.BURN_EDGE_ALPHA, 1.0, FxPainter.BURN_EDGE_ALPHA, 1.0],
			"the corner of the L")
	assert_eq(ContentDB.abilities[&"F08"].fx_tiles, &"burning_ground", "Burning Ground uses it")


func test_clients_rebuild_the_same_shapes() -> void:
	# What the host sends is all a shape needs: two painters given the same event
	# draw the same pieces in the same places.
	var at := _open_ground()
	hero.move.place(at)
	var e := {"type": "fx", "fx": &"water_whip_ribbon", "source": hero.id, "ability": &"W02", "from": hero.move.pos,
			"to": hero.move.pos + Vector2(3, 1), "at": 1.0}
	e.merge(sim.shape_fx_data(hero, ContentDB.abilities[&"W02"], &"water_whip_ribbon", null, e.to), true)
	var f := {"type": "fx", "fx": &"breath_of_fire", "source": hero.id, "ability": &"F14", "from": hero.move.pos,
			"to": hero.move.pos + Vector2(3, 0), "at": 1.0}
	f.merge(sim.shape_fx_data(hero, ContentDB.abilities[&"F14"], &"breath_of_fire", null, f.to), true)
	var shapes := []
	for k in 2:
		var painter := FxPainter.new()
		# Over the network: the event as bytes and back.
		painter.on_events(bytes_to_var(var_to_bytes([e, f])), ContentDB.effects)
		var items := painter.items(1.2, [hero], [], ContentDB.abilities, ContentDB.effects, func(_a): return null)
		shapes.append(items.filter(func(i): return i.has("quad") or (i.has("fx") and not i.has("particle"))) \
				.map(func(i): return [i.get("a", Vector3()), i.get("b", Vector3()), i.pos]))
	assert_gt(shapes[0].size(), 5)
	assert_eq(shapes[0], shapes[1])


func test_effects_drawn_in_code_have_what_they_need() -> void:
	for fx: FxDef in ContentDB.effects.values():
		if fx.ribbon and fx.path == FxDef.Path.VERLET:
			assert_not_null(fx.feel, "%s: its feel" % fx.id)
		elif fx.ribbon:
			assert_not_null(fx.sheet, "%s: its strip" % fx.id)
		if fx.front:
			assert_true(ContentDB.effects.has(fx.head_fx), "%s: its front piece" % fx.id)
		for id in [fx.tip_fx, fx.head_fx, fx.impact_fx, fx.hand_fx, fx.trail_fx, fx.blocked_fx]:
			if id != &"":
				assert_true(ContentDB.effects.has(id), "%s names %s" % [fx.id, id])
