extends GutTest
## Fire physics, phase 3: the gameplay of the Fire abilities built with the look
## (Fire Stream, Overheat, Jet Propulsion, Phoenix Kick, Flame Wheel, Inferno, Breath of
## Fire, Combustion Blast) and the changed ones (Fire Whip's constant hit time, Fireball
## at the aimed point, no draft bars).

const ContentDBScript := preload("res://autoload/content_db.gd")

var db
var world: WorldSim
var hero: Hero
var foe: Enemy


func before_all() -> void:
	db = ContentDBScript.new()


func after_all() -> void:
	db.free()


func before_each() -> void:
	var rules: CombatRules = db.rules.duplicate()
	rules.out_of_combat_hp_regen_percent = 0.0
	rules.out_of_combat_mana_regen_percent = 0.0
	rules.in_combat_mana_regen_percent = 0.0
	rules.party_scaling = false
	var zone := ZoneDef.new()
	zone.id = &"arena"
	var heights: PackedStringArray = []
	var walk: PackedStringArray = []
	for y in 20:
		heights.append("0".repeat(20))
		walk.append(".".repeat(20))
	zone.height_rows = heights
	zone.walk_rows = walk
	zone.graveyards = [Vector2i(0, 0)]
	zone.hero_spawns = [Vector2i(5, 5)]
	world = WorldSim.new(zone, rules, 3)
	var def := EnemyDef.new()
	def.id = &"dummy"
	def.stats = StatBlock.make({Stat.Id.HP: 5000})
	def.aggro_radius = 0
	def.immobile = true
	foe = world.add_enemy(def, Vector2i(8, 5))
	var hd := HeroDef.new()
	hd.base_stats = StatBlock.make({Stat.Id.HP: 500, Stat.Id.MANA: 900, Stat.Id.MAG_ATK: 10, Stat.Id.JUMP: 2})
	hero = world.add_hero(hd)
	for id in ["F06", "F07", "F10", "F11", "F12", "F14", "F15", "F16", "F18", "F23"]:
		TreeRules.master(hero, _a(id))
	hero.growth.set_stat(Stat.Id.FIRE_MASTERY, 0) # learning them gave Fire Mastery: start at none
	hero.refresh_stats()
	world.step()


func _a(id: String) -> AbilityDef:
	return db.abilities[StringName(id)]


func _lost(actor: Actor) -> float:
	return actor.current_stats(world.now).hp - actor.hp


func _cast(id: String, target: Actor = null, aim: Variant = null) -> AbilityResolver.Result:
	hero.mana = 900.0
	return world.cast(hero, _a(id), target, aim)


func test_no_draft_bars_on_kick_dart_whip_fireball_combo() -> void:
	for id in ["F02", "F03", "F06", "F07", "F09"]:
		assert_null(_a(id).timing_bar, id)


func test_fire_whip_cracks_0_75_s_after_the_cast_near_or_far() -> void:
	for spot in [Vector2i(6, 5), Vector2i(9, 5)]:
		foe.move.place(spot)
		foe.hp = foe.current_stats(world.now).hp
		hero.cooldowns = Cooldowns.new()
		assert_eq(_cast("F06", null, Vector2(spot)), AbilityResolver.Result.OK)
		world.advance(0.7)
		assert_eq(_lost(foe), 0.0, "not yet at %s" % spot)
		world.advance(0.1)
		assert_gt(_lost(foe), 0.0, "cracked at %s" % spot)


func test_fire_stream_reaches_further_with_fire_mastery() -> void:
	foe.move.place(Vector2i(9, 5)) # 4 tiles away
	_cast("F12", null, Vector2(9, 5))
	world.advance(2.1)
	assert_eq(_lost(foe), 0.0, "about 2.25 tiles at no Mastery")
	hero.growth.set_stat(Stat.Id.FIRE_MASTERY, 1000)
	hero.refresh_stats()
	hero.cooldowns = Cooldowns.new()
	_cast("F12", null, Vector2(9, 5))
	world.advance(2.1)
	assert_gt(_lost(foe), 0.0, "about 5.2 tiles at 1000")


func test_overheat_grows_each_second_then_bursts_around_the_target() -> void:
	var near := world.add_enemy(foe.def, Vector2i(9, 6))
	assert_eq(_cast("F23", foe), AbilityResolver.Result.OK)
	world.advance(1.05)
	var first := _lost(foe)
	world.advance(1.0)
	var second := _lost(foe) - first
	assert_gt(second, first, "the second tick burns more than the first")
	assert_eq(_lost(near), 0.0, "the burst waits for the end")
	world.advance(6.5)
	assert_gt(_lost(near), 0.0, "the end bursts on the tiles around it")


func test_jet_propulsion_flies_then_lands_on_walkable_ground() -> void:
	assert_eq(_cast("F11"), AbilityResolver.Result.OK)
	assert_true(hero.buffs.is_flying(world.now))
	world.advance(3.2)
	assert_false(hero.buffs.is_flying(world.now))
	assert_true(world.grid.is_walkable(hero.tile()))


func test_phoenix_kick_lands_a_tile_short_and_hits_around_when_it_lands() -> void:
	foe.move.place(Vector2i(10, 5))
	assert_eq(_cast("F15", foe), AbilityResolver.Result.OK)
	assert_eq(_lost(foe), 0.0, "nothing until it comes down")
	world.advance(0.6)
	assert_almost_eq(hero.move.pos.distance_to(foe.move.pos), 1.0, 0.2, "a tile short of it")
	assert_gt(_lost(foe), 0.0, "the crash")


func test_flame_wheel_hits_everyone_around() -> void:
	foe.move.place(Vector2i(6, 5))
	var other := world.add_enemy(foe.def, Vector2i(4, 5))
	assert_eq(_cast("F10"), AbilityResolver.Result.OK)
	world.advance(0.1)
	assert_gt(_lost(foe), 0.0)
	assert_gt(_lost(other), 0.0)


func test_inferno_burns_the_tiles_of_its_block_circle() -> void:
	var tiles := CastResolver.block_circle_tiles(world.grid, Vector2(10, 10), 2.5)
	assert_eq(tiles.size(), 25, "centred on a tile: 25 tiles hold a block of the 2.5-tile circle")
	assert_true(Vector2i(12, 10) in tiles and not (Vector2i(13, 10) in tiles))
	foe.move.place(Vector2i(8, 6))
	assert_eq(_cast("F16", null, Vector2(8, 8)), AbilityResolver.Result.OK)
	world.advance(0.5)
	assert_eq(_lost(foe), 0.0, "warned 0.75 s first")
	world.advance(2.0)
	assert_gt(_lost(foe), 0.0, "then it burns")


func test_breath_of_fire_reaches_5_tiles_and_lowers_magic_defense() -> void:
	foe.move.place(Vector2i(10, 5)) # 5 tiles
	assert_eq(_cast("F14", null, Vector2(10, 5)), AbilityResolver.Result.OK)
	world.advance(0.1)
	assert_gt(_lost(foe), 0.0)
	assert_true(foe.buffs.has(&"breath_scorched", world.now))


func test_fireball_bursts_at_the_aimed_point() -> void:
	foe.move.place(Vector2i(9, 7)) # off the line, but beside the aimed point
	assert_eq(_cast("F07", null, Vector2(9, 6)), AbilityResolver.Result.OK)
	world.advance(1.0)
	assert_gt(_lost(foe), 0.0, "it burst where it was aimed, catching the dummy beside it")


func test_combustion_blast_explodes_after_1_s() -> void:
	foe.move.place(Vector2i(14, 5))
	assert_eq(_cast("F18", null, Vector2(14, 5)), AbilityResolver.Result.OK)
	world.advance(0.9)
	assert_eq(_lost(foe), 0.0)
	world.advance(0.2)
	assert_gt(_lost(foe), 0.0)


func test_cast_events_carry_the_fire_look() -> void:
	_cast("F10")
	var ev: Array = world._events.filter(func(e): return e.get("type", "") == "cast" and e.get("fire", false))
	assert_eq(ev.size(), 1)
	if ev.size() == 1:
		assert_true(ev[0].has("from") and ev[0].has("to") and ev[0].has("mastery") and ev[0].has("at"))
