extends GutTest
## The Sunscale Drake: art (mirrored facings, timing, recolour), flight, Talon Rake,
## Sunfire Breath, Searing Dive, grounding by Air knockbacks, Molten Fury, death.

var world: WorldSim
var hero: Hero
var drake_def: EnemyDef


func before_each() -> void:
	var zone := ZoneDef.new()
	zone.id = &"plain"
	var rows: PackedStringArray = []
	var walk: PackedStringArray = []
	for y in 20:
		rows.append("0".repeat(20))
		walk.append(".".repeat(20))
	zone.height_rows = rows
	zone.walk_rows = walk
	zone.graveyards = [Vector2i(0, 0)]
	zone.hero_spawns = [Vector2i(0, 0)]
	world = WorldSim.new(zone, ContentDB.rules, 3)
	drake_def = ContentDB.enemies[&"sunscale_drake"]
	hero = _hero(Vector2i(2, 10))


func _hero(at: Vector2i) -> Hero:
	var hd := HeroDef.new()
	hd.base_stats = StatBlock.make({Stat.Id.HP: 5000, Stat.Id.JUMP: 2})
	var h := world.add_hero(hd)
	h.move.place(at)
	return h


func _run(seconds: float) -> Array:
	var events := []
	for i in roundi(seconds / world.rules.tick_seconds):
		events.append_array(world.step())
	return events


func _damage_to(events: Array, unit: Actor, ability: StringName) -> float:
	var total := 0.0
	for e in events:
		if e.type == "damage" and e.target == unit.id and e.get("ability", &"") == ability:
			total += float(e.amount)
	return total


## A drake that only knows `ability` (so the test controls which attack it uses).
func _drake_with(ability: StringName, at: Vector2i) -> Enemy:
	var def: EnemyDef = drake_def.duplicate()
	def.abilities = [ContentDB.abilities[ability]] as Array[AbilityDef]
	var d := world.add_enemy(def, at)
	d.threat.add(hero.id, 1.0)
	return d


func test_art_facings_timing_and_recolour() -> void:
	var art := drake_def.art
	assert_eq(art.frame_size, Vector2i(160, 128))
	assert_eq(art.frame_count("breath"), 8)
	assert_eq(art.frame_count("dive"), 18, "10 poised frames for the 1 s lane, then the 8 dive frames")
	assert_eq(art.frame_count("death"), 16)
	assert_almost_eq(ContentDB.abilities[&"talon_rake"].windup_seconds, 0.5, 0.001, "talons swing through kick frame 13")
	assert_almost_eq(ContentDB.abilities[&"sunfire_breath"].windup_seconds, 0.8, 0.001, "rear back 16-19 at 5 fps")
	assert_almost_eq(ContentDB.abilities[&"searing_dive"].windup_seconds, 1.0, 0.001, "1 s lane")
	# Right-facing rows are the left-facing ones mirrored.
	var img: Image = art.sheets["idle"].get_image()
	for p in [Vector2i(70, 60), Vector2i(85, 80), Vector2i(60, 95)]:
		assert_eq(img.get_pixelv(Vector2i(159 - p.x, 128 + p.y)), img.get_pixelv(Vector2i(p.x, p.y)), "SE mirrors SW at %s" % p)
		assert_eq(img.get_pixelv(Vector2i(159 - p.x, 384 + p.y)), img.get_pixelv(Vector2i(p.x, 256 + p.y)), "NE mirrors NW at %s" % p)
	assert_true(art.recolor)
	var params := art.recolor_params()
	for key in ["dark_color", "mid_color", "light_color", "strength"]:
		assert_true(params.has(key), key)
	assert_true(drake_def.elite)
	assert_true(drake_def.flying)


func test_it_flies_over_low_walls_and_water_but_not_tall_ones() -> void:
	var g := world.grid
	g.set_tile(Vector2i(5, 5), 1, false) # a low wall (1 level)
	g.set_tile(Vector2i(6, 5), 2, false) # a 2-level wall
	g.set_tile(Vector2i(7, 5), 6, true) # a high walkable pillar
	var d := world.add_enemy(drake_def, Vector2i(4, 5))
	assert_true(world.can_move(d, Vector2i(4, 5), Vector2i(5, 5)), "over a low wall")
	assert_false(world.can_move(hero, Vector2i(4, 5), Vector2i(5, 5)), "heroes can't")
	assert_false(world.can_move(d, Vector2i(6, 4), Vector2i(6, 5)), "not over a 2-level wall")
	assert_true(world.can_move(d, Vector2i(7, 4), Vector2i(7, 5)), "up any walkable height")
	assert_false(world.can_move(hero, Vector2i(7, 4), Vector2i(7, 5)), "heroes need the Jump")
	var across := world.path_for(d, Vector2i(5, 4), {})
	assert_false(across.is_empty())
	var through := world.path_for(d, Vector2i(5, 5), {})
	assert_eq(through.back(), Vector2i(5, 5), "it can hover over the wall tile")


func test_burning_ground_does_not_touch_it_in_the_air() -> void:
	var d := world.add_enemy(drake_def, Vector2i(10, 2))
	var hp := d.hp
	var burn := _drake_with(&"talon_rake", Vector2i(15, 15)) # any source of burning ground
	var events: Array[Dictionary] = []
	AbilityResolver.apply_area_effects(world.ctx, hero, ContentDB.abilities[&"sunfire_breath"], [Vector2i(10, 2)], events)
	world._handle_requests()
	_run(1.5)
	assert_eq(d.hp, hp, "airborne: the flames below don't reach it")
	d.buffs.apply(drake_def.grounded_buff, world.now)
	AbilityResolver.apply_area_effects(world.ctx, hero, ContentDB.abilities[&"sunfire_breath"], [Vector2i(10, 2)], events)
	world._handle_requests()
	_run(1.0)
	assert_lt(d.hp, hp, "grounded, it burns like anyone")
	burn.die()


func test_talon_rake_hits_the_hero_beside_it() -> void:
	var d := _drake_with(&"talon_rake", Vector2i(3, 10))
	world.step()
	assert_eq(d.casting.get("ability").id, &"talon_rake")
	var events := _run(0.6)
	assert_gt(_damage_to(events, hero, &"talon_rake"), 0.0)


func test_breath_cone_telegraph_matches_the_damage_and_burns() -> void:
	var d := _drake_with(&"sunfire_breath", Vector2i(6, 10))
	var beside := _hero(Vector2i(4, 11)) # inside the cone (row 2 is 3 wide)
	var outside := _hero(Vector2i(4, 14)) # well off to the side
	world.step()
	assert_eq(d.casting.get("ability").id, &"sunfire_breath")
	var marks: Array = world.pending_hits()
	assert_eq(marks.size(), 1, "the cone is outlined on the ground")
	var cone: Array = marks[0].tiles
	assert_true(cone.has(hero.tile()) and cone.has(beside.tile()))
	assert_false(cone.has(outside.tile()))
	assert_almost_eq(float(marks[0].at) - world.now, 0.8, 0.06, "for 0.8 s")
	var events := _run(0.85)
	assert_gt(_damage_to(events, hero, &"sunfire_breath"), 0.0, "in the cone: burned")
	assert_gt(_damage_to(events, beside, &"sunfire_breath"), 0.0)
	assert_eq(_damage_to(events, outside, &"sunfire_breath"), 0.0, "outside: untouched")
	var zones: Array = world.ground_zones()
	assert_eq(zones.size(), 1, "the cone keeps burning")
	assert_eq(Array(zones[0].tiles).size(), cone.size(), "on exactly the cone's tiles")
	assert_almost_eq(float(zones[0].until) - world.now, 3.0, 0.1, "for 3 s")


func test_stepping_out_of_the_cone_dodges_the_breath() -> void:
	_drake_with(&"sunfire_breath", Vector2i(6, 10))
	world.step()
	hero.move.place(Vector2i(2, 16))
	var events := _run(0.85)
	assert_eq(_damage_to(events, hero, &"sunfire_breath"), 0.0)


func test_dive_lane_telegraph_matches_the_damage_shoves_aside_and_trails_fire() -> void:
	var d := _drake_with(&"searing_dive", Vector2i(8, 10)) # the hero is 6 tiles west...
	hero.move.place(Vector2i(5, 10)) # ...now 3, in the lane
	world.step()
	assert_eq(d.casting.get("ability").id, &"searing_dive")
	var lane: Array = world.pending_hits()[0].tiles
	assert_eq(lane, [Vector2i(7, 10), Vector2i(6, 10), Vector2i(5, 10), Vector2i(4, 10), Vector2i(3, 10)], "a 5-tile lane")
	var events := _run(1.05)
	assert_gt(_damage_to(events, hero, &"searing_dive_hit"), 0.0, "hit in the lane")
	assert_ne(hero.tile().y, 10, "shoved out of the lane")
	assert_eq(hero.tile().x, 5)
	assert_eq(d.move.to_tile, Vector2i(3, 10), "dove the whole lane")
	var trail := {}
	for z in world.ground_zones():
		for t in z.tiles:
			trail[t] = true
	for t in lane:
		assert_true(trail.has(t), "fire trail on %s" % t)


func test_out_of_the_lane_takes_no_dive_damage() -> void:
	_drake_with(&"searing_dive", Vector2i(8, 10))
	hero.move.place(Vector2i(5, 10))
	world.step()
	hero.move.place(Vector2i(5, 12))
	var events := _run(1.05)
	assert_eq(_damage_to(events, hero, &"searing_dive_hit"), 0.0)


func test_air_knockback_grounds_it_and_it_takes_more_damage() -> void:
	var d := world.add_enemy(drake_def, Vector2i(3, 10))
	var palm: AbilityDef = ContentDB.abilities[&"A01"]
	var events: Array[Dictionary] = []
	world.ctx.cast_dir = Vector2i(1, 0)
	AbilityResolver.apply_effects(world.ctx, hero, palm, d, events)
	assert_true(events.any(func(e): return e.type == "grounded"))
	assert_true(d.buffs.is_stunned(world.now), "stunned")
	assert_false(d.airborne(world.now), "on the ground")
	assert_almost_eq(d.buffs.damage_taken_multiplier(world.now), 1.25, 0.001, "takes 25% more")
	assert_eq(d.tile(), Vector2i(3, 10), "heavy: a 1-tile palm doesn't move it, but still grounds it")
	_run(3.1)
	assert_true(d.airborne(world.now), "back in the air after 3 s")


func test_other_knockbacks_do_not_ground_it() -> void:
	var d := world.add_enemy(drake_def, Vector2i(3, 10))
	var wave: AbilityDef = ContentDB.abilities[&"W06"]
	var events: Array[Dictionary] = []
	world.ctx.cast_dir = Vector2i(1, 0)
	AbilityResolver.apply_effects(world.ctx, hero, wave, d, events)
	assert_false(events.any(func(e): return e.type == "grounded"))
	assert_true(d.airborne(world.now))


func test_molten_fury_below_30_percent() -> void:
	var d := _drake_with(&"sunfire_breath", Vector2i(6, 10))
	d.hp = d.stats.hp * 0.35
	world.step()
	assert_false(d.buffs.has(&"molten_fury", world.now), "not yet at 35%")
	d.hp = d.stats.hp * 0.25
	var events := _run(0.1)
	assert_true(d.buffs.has(&"molten_fury", world.now), "enraged at 25%")
	assert_true(events.any(func(e): return e.type == "enrage"))
	assert_almost_eq(d.buffs.cooldown_multiplier(world.now), 0.7, 0.001, "cooldowns 30% shorter")
	assert_almost_eq(d.buffs.zone_seconds_bonus(world.now), 2.0, 0.001)
	d.casting = {}
	d.cooldowns = Cooldowns.new()
	world.cast(d, ContentDB.abilities[&"sunfire_breath"], null, Vector2(hero.tile()))
	_run(0.85)
	var zones: Array = world.ground_zones()
	assert_gt(zones.size(), 0)
	assert_almost_eq(float(zones.back().until) - world.now, 5.0, 0.1, "burning ground lasts 5 s")
	assert_almost_eq(d.cooldowns.ability_remaining(&"sunfire_breath", world.now), 10.0 * 0.7 - 0.85, 0.1)


func test_death_plays_once_then_fades() -> void:
	var d := world.add_enemy(drake_def, Vector2i(10, 10))
	d.die()
	d.died_at = 1.0
	var anim := CreatureAnimator.new()
	var art := drake_def.art
	assert_eq(anim.pick(d, art, 1.0).anim, "death")
	assert_eq(anim.pick(d, art, 1.0 + 1.55).frame, 15, "the last Dying frame")
	assert_eq(anim.pick(d, art, 1.0 + 2.0).frame, 15, "then holds it")
	assert_lt(float(anim.pick(d, art, 1.0 + 1.6 + 1.0 + 0.5).alpha), 1.0, "fading")
	assert_true(anim.pick(d, art, 1.0 + 1.6 + 2.1).is_empty(), "gone")
