extends GutTest
## Dungeon rules (apply to every dungeon): instanced per party, a minimum party
## size (3, or 1 with the "testing" setting), and a party wipe that wakes everyone
## at the entrance. Lifts move heroes within one map.

const QUEST := &"test_cave_quest"

var rules: CombatRules
var world: World
var quest: QuestDef


func _rows(w: int, h: int, c: String) -> PackedStringArray:
	var rows: PackedStringArray = []
	for y in h:
		rows.append(c.repeat(w))
	return rows


func _town() -> ZoneDef:
	var z := ZoneDef.new()
	z.id = &"town"
	z.height_rows = _rows(12, 12, "0")
	z.walk_rows = _rows(12, 12, ".")
	z.hero_spawns = [Vector2i(1, 1)] as Array[Vector2i]
	z.graveyards = [Vector2i(1, 1)] as Array[Vector2i]
	var door := ZoneExit.new()
	door.tile = Vector2i(6, 6)
	door.to_zone = &"cave"
	door.to_tile = Vector2i(2, 2)
	z.exits = [door] as Array[ZoneExit]
	return z


func _cave() -> ZoneDef:
	var z := ZoneDef.new()
	z.id = &"cave"
	z.dungeon = true
	z.requires_quest = QUEST
	z.height_rows = _rows(16, 12, "0")
	z.walk_rows = _rows(16, 12, ".")
	z.hero_spawns = [Vector2i(2, 2)] as Array[Vector2i]
	z.graveyards = [Vector2i(1, 2)] as Array[Vector2i]
	var lift := ZoneExit.new() # a lift down to the far end of the same map
	lift.tile = Vector2i(5, 2)
	lift.to_tile = Vector2i(13, 9)
	z.exits = [lift] as Array[ZoneExit]
	var wolf := EnemyDef.new()
	wolf.id = &"cave_wolf"
	wolf.stats.hp = 200.0
	var spawn := EnemySpawn.new()
	spawn.enemy = wolf
	spawn.tile = Vector2i(12, 2)
	z.enemy_spawns = [spawn] as Array[EnemySpawn]
	return z


func before_each() -> void:
	rules = CombatRules.new()
	quest = QuestDef.new()
	quest.id = QUEST
	world = World.new([_town(), _cave()], rules, 3, &"town", {QUEST: quest})


func _hero(with_quest := true) -> Hero:
	var h := world.add_saved_hero(CharacterData.new_character("H%d" % world.heroes().size(),
			ContentDB.heroes[&"adventurer"]), ContentDB)
	h.move.place(world.zone(&"town").find_free_tile_near(Vector2i(2 + world.heroes().size(), 1)))
	if with_quest:
		QuestLog.accept(h, quest)
	world.step()
	return h


## Walks `h` onto the dungeon door (a step onto the tile, as a client would).
func _enter(h: Hero) -> Array[Dictionary]:
	h.move.place(Vector2i(6, 6))
	return world.step()


func test_a_dungeon_has_no_copy_until_a_party_enters() -> void:
	assert_eq(world.zone_ids(), [&"town"])
	assert_true(world.is_dungeon(&"cave"))


func test_entry_needs_a_party_of_three_in_the_real_game() -> void:
	var a := _hero()
	_hero()
	var events := _enter(a)
	var no := events.filter(func(e): return e.type == "rejected" and e.target == a.id)
	assert_eq(no.size(), 1)
	assert_eq(no[0].reason, "dungeon_party_too_small")
	assert_eq(no[0].need, 3)
	assert_eq(world.zone_of(a.id).key, &"town", "stays outside")
	_hero()
	a.move.place(Vector2i(6, 7))
	world.step()
	events = _enter(a)
	assert_true(events.any(func(e): return e.type == "dungeon_enter" and e.target == a.id))
	assert_eq(world.zone_of(a.id).key, &"cave@party")
	assert_eq(world.zone_of(a.id).zone.id, &"cave", "clients load the cave's map")


func test_testing_setting_lets_one_hero_in() -> void:
	var a := _hero()
	rules.dungeon_testing = true
	assert_eq(rules.min_dungeon_party(), 1)
	_enter(a)
	assert_eq(world.zone_of(a.id).key, &"cave@party")
	assert_eq(a.tile(), Vector2i(2, 2))


func test_debug_builds_start_with_testing_on() -> void:
	world.enable_debug(ContentDB)
	assert_true(rules.dungeon_testing)


func test_testing_setting_is_a_debug_intent() -> void:
	var a := _hero()
	world.submit(a.id, Intents.sanitize({"type": "dungeon_testing", "on": true}))
	var events := world.step()
	assert_true(events.any(func(e): return e.type == "rejected" and e.reason == "debug_disabled"))
	assert_false(rules.dungeon_testing)
	world.enable_debug(ContentDB)
	world.submit(a.id, Intents.sanitize({"type": "dungeon_testing", "on": false}))
	events = world.step()
	assert_true(events.any(func(e): return e.type == "dungeon_testing" and e.on == false))
	assert_false(rules.dungeon_testing)


func test_entry_needs_the_dungeons_quest() -> void:
	rules.dungeon_testing = true
	var a := _hero(false)
	var events := _enter(a)
	assert_true(events.any(func(e): return e.type == "rejected" and e.reason == "dungeon_needs_quest"))
	assert_eq(world.zone_of(a.id).key, &"town")


func test_the_party_shares_one_copy_and_it_closes_when_empty() -> void:
	rules.dungeon_testing = true
	var a := _hero()
	var b := _hero()
	_enter(a)
	b.move.place(Vector2i(6, 6))
	world.step()
	assert_same(world.zone_of(a.id), world.zone_of(b.id), "one copy per party")
	var copy := world.zone_of(a.id)
	assert_eq(copy.tick_count, world.zone(&"town").tick_count, "on the world's clock")
	world.move_hero(a.id, &"town", Vector2i(1, 1))
	world.move_hero(b.id, &"town", Vector2i(2, 1))
	world.advance(rules.dungeon_close_seconds - 1.0)
	assert_true(world.zone_ids().has(&"cave@party"), "kept a while")
	world.advance(2.0)
	assert_false(world.zone_ids().has(&"cave@party"), "closed")
	_enter(a)
	assert_ne(world.zone_of(a.id), copy, "a fresh copy next time")


func test_a_lift_moves_within_the_map() -> void:
	rules.dungeon_testing = true
	var a := _hero()
	_enter(a)
	var copy := world.zone_of(a.id)
	a.move.place(Vector2i(5, 2))
	var events := world.step()
	assert_true(events.any(func(e): return e.type == "lift" and e.target == a.id))
	assert_eq(a.tile(), Vector2i(13, 9))
	assert_same(world.zone_of(a.id), copy)


func test_a_party_wipe_wakes_everyone_at_the_entrance() -> void:
	rules.dungeon_testing = true
	var a := _hero()
	var b := _hero()
	_enter(a)
	b.move.place(Vector2i(6, 6))
	world.step()
	var copy := world.zone_of(a.id)
	var wolf: Enemy = copy.enemies()[0]
	for h in [a, b]:
		h.move.place(copy.find_free_tile_near(Vector2i(11, 3)))
		wolf.threat.add(h.id, 10.0)
	wolf.state = Enemy.State.COMBAT
	a.hp = 0.0
	a.die()
	var events := world.step()
	assert_false(events.any(func(e): return e.type == "party_wipe"), "one still stands")
	b.die()
	events = world.step()
	assert_true(events.any(func(e): return e.type == "party_wipe"))
	events = world.advance(rules.wipe_respawn_seconds + 0.1)
	assert_true(events.any(func(e): return e.type == "wipe_respawn"))
	for h in [a, b]:
		assert_true(h.alive, "%s stands up" % h.display_name)
		assert_lte(GridModel.distance(h.tile(), Vector2i(1, 2)), 2, "at the entrance")
		assert_almost_eq(h.hp, h.current_stats(world.now).hp * rules.release_fraction, 3.0)
	assert_false(wolf.threat.ids().has(a.id), "enemies forget the party")


func test_no_wipe_outside_dungeons() -> void:
	var a := _hero()
	a.die()
	var events := world.advance(rules.wipe_respawn_seconds + 0.5)
	assert_false(events.any(func(e): return e.type == "party_wipe" or e.type == "wipe_respawn"))
	assert_false(a.alive, "releases as usual")
