extends GutTest
## The Salamander Hound: art timing, Bite, Cinder Pounce (a telegraphed leap
## beside its prey) and Ember Trail (burning tiles behind it).

var world: WorldSim
var hero: Hero
var hound_def: EnemyDef


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
	hound_def = ContentDB.enemies[&"salamander_hound"]
	var hd := HeroDef.new()
	hd.base_stats = StatBlock.make({Stat.Id.HP: 5000, Stat.Id.JUMP: 2})
	hero = world.add_hero(hd)
	hero.move.place(Vector2i(2, 10))


func _run(seconds: float) -> Array:
	var events := []
	for i in roundi(seconds / world.rules.tick_seconds):
		events.append_array(world.step())
	return events


func test_data_and_art() -> void:
	assert_eq(hound_def.display_name, "Salamander Hound")
	assert_lt(hound_def.combat_step_seconds, ContentDB.enemies[&"wolf"].combat_step_seconds, "faster than a wolf")
	assert_lt(hound_def.stats.hp, ContentDB.enemies[&"wolf"].stats.hp, "low-to-mid HP")
	var art := hound_def.art
	assert_eq(art.frame_size, Vector2i(48, 48))
	assert_eq(art.frame_count("idle"), 16, "the authored loop")
	for anim in ["idle", "run", "bite", "pounce", "death"]:
		assert_gt(art.frame_count(anim), 0, anim)
		assert_true(art.flash_sheets.has(anim), "flash sheet for " + anim)
	var bite: AbilityDef = ContentDB.abilities[&"hound_bite"]
	var pounce: AbilityDef = ContentDB.abilities[&"cinder_pounce"]
	assert_almost_eq(bite.windup_seconds, 0.3, 0.001, "jaws on frame 6 at 20 fps")
	assert_almost_eq(pounce.windup_seconds, 0.6, 0.001, "springs on frame 6 at 10 fps")
	assert_eq(pounce.cooldown_seconds, 8.0)


func test_pounce_marks_the_tile_beside_the_hero_then_lands_and_burns() -> void:
	var hound := world.add_enemy(hound_def, Vector2i(5, 10)) # 3 tiles away
	world.step()
	assert_eq(hound.casting.get("ability").id, &"cinder_pounce", "pounces from 3 tiles")
	var marks: Array = world.pending_hits()
	assert_eq(marks.size(), 1, "the landing is telegraphed")
	var tiles: Array = marks[0].tiles
	assert_true(tiles.has(Vector2i(3, 10)), "lands beside the hero, on its own side")
	assert_true(tiles.has(Vector2i(2, 10)), "the hero stands on the mark")
	assert_eq(tiles.size(), 5, "the landing tile and its four neighbours")
	var hp := hero.hp
	_run(0.65)
	assert_lt(hero.hp, hp, "burned for staying on the mark")
	assert_eq(hound.tile(), Vector2i(3, 10), "leapt next to its prey")


func test_stepping_off_the_mark_dodges_the_pounce() -> void:
	var hound := world.add_enemy(hound_def, Vector2i(5, 10))
	world.step()
	assert_eq(hound.casting.get("ability").id, &"cinder_pounce")
	hero.move.place(Vector2i(2, 11)) # one step sideways: diagonal to the landing tile
	var hp := hero.hp
	var events := _run(0.65)
	assert_eq(hero.hp, hp, "no damage off the marker")
	assert_false(events.any(func(e): return e.type == "damage" and e.target == hero.id))


func test_bites_when_beside_the_hero() -> void:
	var hound := world.add_enemy(hound_def, Vector2i(3, 10))
	world.step()
	assert_eq(hound.casting.get("ability").id, &"hound_bite", "adjacent: bites rather than pounces")


func test_ember_trail_burns_tiles_it_runs_over() -> void:
	var hound := world.add_enemy(hound_def, Vector2i(9, 10)) # 7 away: chases first
	hound.threat.add(hero.id, 1.0)
	_run(0.6)
	var zones: Array = world.ground_zones()
	assert_gt(zones.size(), 0, "the tile it left is burning")
	assert_eq(zones[0].ability, &"ember_trail")
	var burning: Vector2i = zones[0].tiles[0]
	hero.move.place(burning)
	var hp := hero.hp
	_run(0.6)
	assert_lt(hero.hp, hp, "standing in the embers hurts")
	_run(2.5)
	assert_false(world.ground_zones().any(func(z): return z.tiles.has(burning)), "embers die out after 2 s")


func test_an_idle_hound_leaves_no_trail() -> void:
	var hound := world.add_enemy(hound_def, Vector2i(15, 2))
	hound.patrol = [Vector2i(15, 2), Vector2i(18, 2)] as Array[Vector2i]
	_run(3.0)
	assert_eq(world.ground_zones().size(), 0)
