extends GutTest
## Effect sprites from the approved art (stance rework phase 3, 2026-11-23): every
## ability in content/effects/ability_effects.json has its effects; projectiles are
## pre-rotated; held effects ride on the ability's buffs; Scorch draws flames in
## code with a debuff icon; the `fx` debug command plays an ability's effects.

var world: World
var sim: WorldSim
var hero: Hero


func before_each() -> void:
	ContentDB.rules.timing_bars_enabled = false
	world = World.new(ContentDB.zones.values(), ContentDB.rules, 5, &"town", ContentDB.quests)
	hero = world.add_saved_hero(CharacterData.new_character("Rook", ContentDB.heroes[&"adventurer"]), ContentDB)
	sim = world.zone_of(hero.id)
	sim.debug_content = ContentDB
	world.step()


func after_each() -> void:
	ContentDB.rules.timing_bars_enabled = true


func _table() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(ContentDB.ABILITY_EFFECTS_PATH))


func test_every_listed_effect_exists_and_is_linked() -> void:
	var table := _table()
	var count := 0
	for id in table:
		if id.begins_with("_"):
			continue
		var a: AbilityDef = ContentDB.abilities.get(StringName(id))
		assert_not_null(a, id)
		for role in table[id]:
			var fx: FxDef = ContentDB.effects.get(StringName(table[id][role]))
			assert_not_null(fx, "%s %s" % [id, role])
			if fx == null:
				continue
			assert_not_null(fx.sheet, "%s has its picture" % fx.id)
			assert_eq(a.get(ContentDB.FX_ROLES[role]), fx.id, "%s %s" % [id, role])
			count += 1
	assert_gt(count, 35)


func test_projectiles_are_pre_rotated_from_their_drawn_direction() -> void:
	for id in [&"fireball", &"fire_dart", &"frost_shard", &"metal_shards", &"air_blade"]:
		var fx: FxDef = ContentDB.effects[id]
		assert_true(fx.rotate, id)
		assert_not_null(fx.rot_sheet, "%s has its turned cells" % id)
		if fx.rot_sheet != null:
			assert_eq(fx.rot_sheet.get_width(), fx.rot_sheet.get_height() * fx.rot_steps, "%s: one cell per turn" % id)
	assert_eq(ContentDB.effects[&"fireball"].drawn_angle, 90.0, "the Fireball is drawn facing south")
	assert_eq(ContentDB.effects[&"fire_dart"].drawn_angle, 90.0, "so is the Fire Dart")
	assert_false(ContentDB.effects[&"tornado"].rotate, "a tornado flies upright")


func test_held_effects_ride_on_the_abilities_buffs() -> void:
	var glide: BuffDef = null
	for e in ContentDB.abilities[&"A03"].effects:
		if e.buff != null:
			glide = e.buff
	assert_not_null(glide)
	assert_eq(glide.fx, &"air_step_puff", "Air Step's puff under the feet")
	var scorched: BuffDef = ContentDB.buffs[&"scorched"]
	assert_eq(scorched.code_fx, "flames", "Scorch: flames in code until its art is approved")
	assert_not_null(scorched.icon, "and a debuff icon")
	assert_string_contains(scorched.icon_text, "15%")


func test_painter_draws_buffs_projectiles_and_zones() -> void:
	var painter := FxPainter.new()
	var art_for := func(_a): return null
	hero.buffs.apply(ContentDB.buffs[&"scorched"], sim.now, 0.0, hero.id)
	var proj := {"ability": "F07", "origin": hero.tile(), "from": hero.move.pos, "dirv": Vector2.RIGHT,
			"length": 6.0, "start": sim.now, "speed": 12.0}
	var zone := {"ability": "F05", "tiles": [hero.tile(), hero.tile() + Vector2i(1, 0)], "until": sim.now + 3.0}
	var items := painter.items(sim.now + 0.25, [hero], [], ContentDB.abilities, ContentDB.effects, art_for,
			{"projectiles": [proj], "zones": [zone], "buffs": ContentDB.buffs})
	var codes := items.filter(func(i): return i.get("code", "") == "flames")
	assert_eq(codes.size(), 1, "Scorch's flames on the hero")
	var flying := items.filter(func(i): return i.has("fx") and i.fx.id == &"fireball")
	assert_eq(flying.size(), 1, "the Fireball in flight")
	if flying.size() == 1:
		assert_almost_eq(flying[0].pos.x, hero.move.pos.x + 3.0, 0.01, "12 tiles/s for 0.25 s")
	assert_eq(items.filter(func(i): return i.has("fx") and i.fx.id == &"flame_dash_trail").size(), 2,
			"the trail on each burning tile")


func test_ice_spikes_land_with_their_tiles() -> void:
	hero.mastered[&"W09"] = ContentDB.abilities[&"W09"]
	hero.mana = 999
	sim.cast(hero, ContentDB.abilities[&"W09"], null, hero.move.pos + Vector2(3, 0))
	var found := false
	for i in 40:
		for e in world.step():
			if e.get("type", "") == "fx" and e.get("fx", &"") == &"ice_spikes":
				found = true
				assert_eq(e.tiles.size(), 9, "one spike per tile of the 3x3")
	assert_true(found, "the spikes come up where it lands")


func _debug(line: String, aim: Vector2) -> Array[Dictionary]:
	world.submit(hero.id, {"type": "debug", "line": line, "aim": aim})
	return world.step()


func test_fx_command_plays_an_abilitys_effects_toward_the_cursor() -> void:
	var events := _debug("fx Fireball", hero.move.pos + Vector2(4, 0))
	var fx := events.filter(func(e): return e.get("type", "") == "fx")
	assert_eq(fx.size(), 1, "its flight")
	if fx.size() == 1:
		assert_eq(fx[0].fx, &"fireball")
		assert_gt(float(fx[0].fly), 0.0, "flies at its speed")
	events = _debug("fx W01", hero.move.pos + Vector2(2, 0))
	fx = events.filter(func(e): return e.get("type", "") == "fx")
	assert_eq(fx.map(func(e): return e.fx), [&"heal_ball", &"heal_splash"], "in the hands, then on the target")
	events = _debug("fx F22", hero.move.pos)
	assert_eq(events.filter(func(e): return e.get("code", "") == "flames").size(), 1, "Scorch's code flames")
	var before := hero.hp
	_debug("fx E21", hero.move.pos + Vector2(20, 0))
	assert_eq(hero.hp, before, "no damage")


func test_fx_command_holds_a_stance() -> void:
	_debug("fx Water:5", hero.move.pos)
	assert_eq([hero.stance_tree, hero.stance], ["Water", 5])
