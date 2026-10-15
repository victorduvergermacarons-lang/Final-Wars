extends GutTest
## Effect building blocks, part 2: knockback and pull, dash/leap/blink, terrain
## raise/lower and walls, persistent ground zones, counters and reflects, and how
## terrain and zones reach clients.

var rules: CombatRules
var world: WorldSim
var hero: Hero
var foe: Enemy


func before_each() -> void:
	rules = CombatRules.new()
	rules.out_of_combat_hp_regen_percent = 0.0
	rules.out_of_combat_mana_regen_percent = 0.0
	rules.in_combat_mana_regen_percent = 0.0
	var zone := ZoneDef.new()
	zone.id = &"arena"
	var heights: PackedStringArray = []
	var walk: PackedStringArray = []
	for y in 15:
		heights.append("0".repeat(15))
		walk.append(".".repeat(15))
	zone.height_rows = heights
	zone.walk_rows = walk
	zone.graveyards = [Vector2i(0, 0)]
	zone.hero_spawns = [Vector2i(5, 5)]
	var def := EnemyDef.new()
	def.id = &"dummy"
	def.stats = StatBlock.make({Stat.Id.HP: 1000})
	def.aggro_radius = 0
	var spawn := EnemySpawn.new()
	spawn.enemy = def
	spawn.tile = Vector2i(6, 5)
	zone.enemy_spawns = [spawn]
	world = WorldSim.new(zone, rules, 3)
	foe = world.enemies()[0]
	var hd := HeroDef.new()
	hd.base_stats = StatBlock.make({Stat.Id.HP: 500, Stat.Id.MANA: 500})
	hero = world.add_hero(hd)
	world.step()
	foe.face(Vector2i(-1, 0)) # faces the hero: no flank bonus


func _effect(kind: AbilityEffect.Kind, base: float, props: Dictionary = {}) -> AbilityEffect:
	var e := AbilityEffect.new()
	e.kind = kind
	e.base_amount = base
	e.can_crit = false
	for k in props:
		e.set(k, props[k])
	return e


func _ability(effects: Array, props: Dictionary = {}) -> AbilityDef:
	var a := AbilityDef.new()
	a.id = StringName("t_%d" % randi())
	a.targeting = AbilityDef.TargetingMode.TARGETED
	a.max_range = 5
	a.on_gcd = false
	var list: Array[AbilityEffect] = []
	list.assign(effects)
	a.effects = list
	for k in props:
		a.set(k, props[k])
	return a


func _ground(effects: Array, props: Dictionary = {}) -> AbilityDef:
	var p := {"targeting": AbilityDef.TargetingMode.GROUND}
	p.merge(props, true)
	return _ability(effects, p)


func _lost(actor: Actor) -> float:
	return actor.stats.hp - actor.hp


func _wall(tile: Vector2i) -> void:
	world.grid.set_tile(tile, 0, false)


func test_knockback_pushes_away() -> void:
	world.cast(hero, _ability([_effect(AbilityEffect.Kind.KNOCKBACK, 3)]), foe)
	assert_eq(foe.tile(), Vector2i(9, 5))


func test_knockback_stops_at_wall_with_impact_damage() -> void:
	_wall(Vector2i(8, 5))
	world.cast(hero, _ability([_effect(AbilityEffect.Kind.KNOCKBACK, 3, {"impact_damage": 20.0})]), foe)
	assert_eq(foe.tile(), Vector2i(7, 5), "stops before the wall")
	assert_eq(_lost(foe), 20.0, "slammed into it")


func test_knockback_without_obstacle_deals_no_impact() -> void:
	world.cast(hero, _ability([_effect(AbilityEffect.Kind.KNOCKBACK, 2, {"impact_damage": 20.0})]), foe)
	assert_eq(_lost(foe), 0.0)


func test_knockback_is_eight_way() -> void:
	foe.move.place(Vector2i(6, 6))
	world.cast(hero, _ability([_effect(AbilityEffect.Kind.KNOCKBACK, 2)]), foe)
	assert_eq(foe.tile(), Vector2i(8, 8), "diagonal push")


func test_pull_stops_next_to_caster() -> void:
	foe.move.place(Vector2i(9, 5))
	world.cast(hero, _ability([_effect(AbilityEffect.Kind.PULL, 10)]), foe)
	assert_eq(foe.tile(), Vector2i(6, 5))


func test_pull_cancels_a_cast() -> void:
	foe.move.place(Vector2i(9, 5))
	foe.casting = {"kind": "cast", "end": world.now + 5.0}
	world.cast(hero, _ability([_effect(AbilityEffect.Kind.PULL, 2)]), foe)
	assert_true(foe.casting.is_empty())


func _lunge() -> AbilityDef:
	return _ability([_effect(AbilityEffect.Kind.DASH_TO, 4, {"applies": AbilityEffect.Applies.CASTER}),
			_effect(AbilityEffect.Kind.DAMAGE, 30)], {"max_range": 4, "hit_range": 1})


func test_lunge_dashes_next_to_target_then_strikes() -> void:
	foe.move.place(Vector2i(9, 5))
	world.cast(hero, _lunge(), foe)
	assert_eq(hero.tile(), Vector2i(8, 5), "stops next to the target")
	assert_eq(_lost(foe), 30.0)


func test_lunge_blocked_by_wall_whiffs() -> void:
	foe.move.place(Vector2i(9, 5))
	_wall(Vector2i(7, 5))
	world.cast(hero, _lunge(), foe)
	assert_eq(hero.tile(), Vector2i(6, 5))
	assert_eq(_lost(foe), 0.0, "too far to strike after the dash")


func test_leap_lands_on_aimed_tile() -> void:
	_wall(Vector2i(5, 6))
	var leap := _ground([_effect(AbilityEffect.Kind.LEAP, 0, {"applies": AbilityEffect.Applies.CASTER})])
	assert_eq(world.cast(hero, leap, null, Vector2(5, 8)), AbilityResolver.Result.OK)
	assert_eq(hero.tile(), Vector2i(5, 8), "over the wall")
	assert_true(hero.move.is_moving(world.now), "a leap takes a moment")


func test_leap_onto_occupied_tile_fails() -> void:
	var leap := _ground([_effect(AbilityEffect.Kind.LEAP, 0, {"applies": AbilityEffect.Applies.CASTER})])
	world.cast(hero, leap, null, Vector2(6, 5))
	assert_eq(hero.tile(), Vector2i(5, 5))


func test_blink_is_instant() -> void:
	var blink := _ground([_effect(AbilityEffect.Kind.BLINK, 0, {"applies": AbilityEffect.Applies.CASTER})])
	world.cast(hero, blink, null, Vector2(2, 4))
	assert_eq(hero.tile(), Vector2i(2, 4))
	assert_false(hero.move.is_moving(world.now))


func _raise(levels: float, seconds: float, props: Dictionary = {}) -> AbilityDef:
	var p := {"applies": AbilityEffect.Applies.AREA, "duration_seconds": seconds}
	p.merge(props, true)
	return _ground([_effect(AbilityEffect.Kind.TERRAIN, levels, p)])


func test_raise_terrain_then_restore() -> void:
	world.cast(hero, _raise(2, 3.0), null, Vector2(7, 7))
	assert_eq(world.grid.height_at(Vector2i(7, 7)), 2)
	assert_eq(world.changed_terrain().size(), 1)
	world.advance(3.1)
	assert_eq(world.grid.height_at(Vector2i(7, 7)), 0, "back to normal")
	assert_true(world.changed_terrain().is_empty())


func test_raised_terrain_lifts_the_unit_on_it() -> void:
	foe.move.place(Vector2i(7, 7))
	world.cast(hero, _raise(3, 3.0), null, Vector2(7, 7))
	assert_eq(world.grid.height_at(foe.tile()), 3)
	assert_eq(foe.tile(), Vector2i(7, 7), "still standing on it")


func test_lowered_terrain_never_goes_below_zero() -> void:
	world.grid.set_tile(Vector2i(7, 7), 1, true)
	world.cast(hero, _raise(-3, 3.0), null, Vector2(7, 7))
	assert_eq(world.grid.height_at(Vector2i(7, 7)), 0)
	world.advance(3.1)
	assert_eq(world.grid.height_at(Vector2i(7, 7)), 1)


func test_wall_line_blocks_movement_and_skips_occupied_tiles() -> void:
	foe.move.place(Vector2i(6, 8))
	var wall := _raise(1, 5.0, {"blocks_movement": true, "wall_line": true})
	world.cast(hero, wall, null, Vector2(5, 8))
	# Facing down (0,1): the wall runs across it, centred on (5,8).
	assert_false(world.grid.is_walkable(Vector2i(4, 8)))
	assert_false(world.grid.is_walkable(Vector2i(5, 8)))
	assert_true(world.grid.is_walkable(Vector2i(6, 8)), "the foe's tile is skipped")
	assert_eq(world.grid.height_at(Vector2i(6, 8)), 0)
	world.advance(5.1)
	assert_true(world.grid.is_walkable(Vector2i(5, 8)))


func test_wall_grows_with_mastery() -> void:
	hero.growth.set_stat(Stat.Id.EARTH_MASTERY, 600)
	hero.refresh_stats()
	var wall := _raise(1, 5.0, {"blocks_movement": true, "wall_line": true, "mastery_per_extra": 300.0})
	wall.tree = "Earth"
	world.cast(hero, wall, null, Vector2(7, 8))
	var blocked := 0
	for x in range(3, 12):
		if not world.grid.is_walkable(Vector2i(x, 8)):
			blocked += 1
	assert_eq(blocked, 5, "3 + 1 per 300 Mastery")


func _zone(seconds: float, tick: float = 1.0) -> AbilityDef:
	var burn := _ability([_effect(AbilityEffect.Kind.DAMAGE, 10)])
	return _ground([_effect(AbilityEffect.Kind.ZONE, 0, {"applies": AbilityEffect.Applies.AREA,
			"duration_seconds": seconds, "zone_ability": burn, "zone_tick_seconds": tick})], {"area_radius": 1})


func test_ground_zone_ticks_on_units_inside() -> void:
	world.cast(hero, _zone(3.0), null, Vector2(6, 5))
	assert_eq(world.ground_zones().size(), 1)
	assert_eq(_lost(foe), 0.0, "first tick after one second")
	world.advance(3.1)
	assert_eq(_lost(foe), 30.0, "three ticks of 10")
	assert_true(world.ground_zones().is_empty(), "gone when it expires")


func test_ground_zone_spares_units_that_leave() -> void:
	world.cast(hero, _zone(3.0), null, Vector2(6, 5))
	world.advance(1.05)
	foe.move.place(Vector2i(10, 10))
	world.advance(2.1)
	assert_eq(_lost(foe), 10.0, "only the tick while it stood there")


func _counter_buff(props: Dictionary) -> BuffDef:
	var b := BuffDef.new()
	b.id = StringName("c_%d" % randi())
	b.duration_seconds = 10.0
	for k in props:
		b.set(k, props[k])
	return b


func test_parry_negates_a_melee_hit_per_charge() -> void:
	hero.buffs.apply(_counter_buff({"negate_hits": true, "charges": 1}), world.now)
	var events: Array[Dictionary] = []
	AbilityResolver.deal_damage(world.ctx, foe, hero, &"hit", 20.0, false, events, "", 1.0, true)
	assert_eq(_lost(hero), 0.0)
	assert_eq(events[0].type, "parry")
	AbilityResolver.deal_damage(world.ctx, foe, hero, &"hit", 20.0, false, events, "", 1.0, true)
	assert_eq(_lost(hero), 20.0, "the charge is used up")


func test_melee_only_parry_ignores_ranged_hits() -> void:
	hero.buffs.apply(_counter_buff({"negate_hits": true}), world.now)
	var events: Array[Dictionary] = []
	AbilityResolver.deal_damage(world.ctx, foe, hero, &"bolt", 20.0, false, events)
	assert_eq(_lost(hero), 20.0)


func test_reflect_sends_damage_back() -> void:
	hero.buffs.apply(_counter_buff({"reflect_fraction": 0.5, "melee_only": false}), world.now)
	var events: Array[Dictionary] = []
	AbilityResolver.deal_damage(world.ctx, foe, hero, &"bolt", 20.0, false, events)
	assert_eq(_lost(hero), 20.0)
	assert_eq(_lost(foe), 10.0)


func test_counter_ability_strikes_the_attacker() -> void:
	var riposte := _ability([_effect(AbilityEffect.Kind.DAMAGE, 15)], {"max_range": 1})
	hero.buffs.apply(_counter_buff({"negate_hits": true, "counter_ability": riposte}), world.now)
	var bite := _ability([_effect(AbilityEffect.Kind.DAMAGE, 20)], {"max_range": 1})
	assert_eq(world.cast(foe, bite, hero), AbilityResolver.Result.OK)
	assert_eq(_lost(hero), 0.0, "parried")
	assert_eq(_lost(foe), 15.0, "riposte")


func test_terrain_and_zones_reach_the_client_mirror() -> void:
	world.cast(hero, _raise(2, 3.0), null, Vector2(7, 7))
	world.cast(hero, _zone(3.0), null, Vector2(3, 3))
	var mirror := ClientWorld.new(world.zone, rules, null)
	var snap := Snapshot.capture(world, hero.id)
	snap.actors = []
	mirror.apply_snapshot(snap)
	assert_eq(mirror.grid.height_at(Vector2i(7, 7)), 2)
	assert_eq(mirror.ground_zones.size(), 1)
	world.advance(3.1)
	snap = Snapshot.capture(world, hero.id)
	snap.actors = []
	mirror.apply_snapshot(snap)
	assert_eq(mirror.grid.height_at(Vector2i(7, 7)), 0, "restored on the client too")
	assert_true(mirror.ground_zones.is_empty())


func test_weight_changes_how_far_units_are_moved() -> void:
	foe.weight = Weight.Id.LIGHT
	world.cast(hero, _ability([_effect(AbilityEffect.Kind.KNOCKBACK, 2)]), foe)
	assert_eq(foe.tile(), Vector2i(9, 5), "light: 1 tile further")
	foe.move.place(Vector2i(6, 5))
	foe.weight = Weight.Id.HEAVY
	world.cast(hero, _ability([_effect(AbilityEffect.Kind.KNOCKBACK, 2)]), foe)
	assert_eq(foe.tile(), Vector2i(7, 5), "heavy: 1 tile less")
	foe.move.place(Vector2i(6, 5))
	world.cast(hero, _ability([_effect(AbilityEffect.Kind.KNOCKBACK, 1)]), foe)
	assert_eq(foe.tile(), Vector2i(6, 5), "a 1-tile push doesn't move a heavy unit")
	foe.move.place(Vector2i(10, 5))
	world.cast(hero, _ability([_effect(AbilityEffect.Kind.PULL, 2)]), foe)
	assert_eq(foe.tile(), Vector2i(9, 5), "heavy pulled 1 instead of 2")


func test_enemy_weights_in_content() -> void:
	var db = load("res://autoload/content_db.gd").new()
	assert_eq(db.enemies[&"goblin_shaman"].weight, Weight.Id.LIGHT)
	assert_eq(db.enemies[&"fen_skirmisher"].weight, Weight.Id.LIGHT)
	assert_eq(db.enemies[&"wolf"].weight, Weight.Id.MEDIUM)
	assert_eq(db.enemies[&"bandit_brute"].weight, Weight.Id.HEAVY)
	assert_eq(db.enemies[&"old_grizzlehide"].weight, Weight.Id.HEAVY)
	assert_eq(Hero.new(1).weight, Weight.Id.MEDIUM, "heroes are medium")
	db.free()


func test_stacked_pillars_come_down_one_by_one() -> void:
	world.cast(hero, _raise(1, 3.0), null, Vector2(7, 7))
	world.advance(1.0)
	world.cast(hero, _raise(1, 3.0), null, Vector2(7, 7))
	assert_eq(world.grid.height_at(Vector2i(7, 7)), 2, "stacked")
	world.advance(2.1)
	assert_eq(world.grid.height_at(Vector2i(7, 7)), 1, "the first one ends; the second still stands")
	world.advance(1.0)
	assert_eq(world.grid.height_at(Vector2i(7, 7)), 0, "then the second")
	world.advance(5.0)
	assert_eq(world.grid.height_at(Vector2i(7, 7)), 0, "and nothing comes back")
	assert_true(world.changed_terrain().is_empty())


func test_overlapping_walls_keep_tiles_blocked_until_the_last_ends() -> void:
	var wall := _raise(1, 3.0, {"blocks_movement": true})
	world.cast(hero, wall, null, Vector2(7, 7))
	world.advance(1.0)
	world.cast(hero, wall, null, Vector2(7, 7))
	world.advance(2.1)
	assert_false(world.grid.is_walkable(Vector2i(7, 7)), "still blocked by the second")
	world.advance(1.0)
	assert_true(world.grid.is_walkable(Vector2i(7, 7)))
