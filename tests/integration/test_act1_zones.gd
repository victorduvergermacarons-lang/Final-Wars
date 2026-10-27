extends GutTest
## Act I milestone 2, the zones: every linked map edge leads where it says and
## back, players spread over different zones at once, released heroes from the
## roads and towns beyond respawn at the Crossing's shrine, and the music follows
## the zone's region as you walk between regions.

const ContentDBScript := preload("res://autoload/content_db.gd")
const SETTINGS := "user://test_act1_zones_settings.cfg"

var db
var world: World


func before_all() -> void:
	db = ContentDBScript.new()


func after_all() -> void:
	db.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS))


func before_each() -> void:
	world = World.new(db.zones.values(), db.rules, 3, &"town", db.quests)
	world.enable_debug(db)


func _hero(hero_name: String) -> Hero:
	return world.add_saved_hero(CharacterData.new_character(hero_name, db.heroes[&"adventurer"]), db)


func _zone_id(h: Hero) -> StringName:
	return world.zone_of(h.id).zone.id


## Walks `h` (in its zone) to `goal` on foot (out of combat).
func _walk(h: Hero, goal: Vector2i) -> bool:
	var sim := world.zone_of(h.id)
	var path := Pathfinder.find_path(sim.grid, h.tile(), goal, 2, sim.occupied_tiles(h), -1, 20000)
	for i in range(1, path.size()):
		world.submit(h.id, {"type": "step", "to": path[i]})
		world.advance(db.rules.walk_tile_seconds + 0.05)
	return h.tile() == goal


## Tiles on zone `z`'s side `side` from which walking off leads into the next zone.
func _edge_tiles(z: ZoneDef, side: Vector2i) -> Array:
	var grid := GridModel.from_zone(z)
	var out := []
	for y in grid.depth:
		for x in grid.width:
			var p := Vector2i(x, y)
			if grid.is_walkable(p) and not grid.in_bounds(p + side):
				out.append(p)
	return out


# --- The map --------------------------------------------------------------------

func test_every_zone_has_its_region_and_music() -> void:
	var expect := {&"town": Regions.Id.HEARTLAND, &"crossing": Regions.Id.HEARTLAND, &"greenfields": Regions.Id.HEARTLAND,
			&"enemy_testing": Regions.Id.HEARTLAND, &"deepcut_road": Regions.Id.BEDRUN, &"deepcut": Regions.Id.BEDRUN,
			&"windsteppe": Regions.Id.VAEL, &"tidereach_shore": Regions.Id.TIDEREACH}
	assert_eq(db.zones.size(), expect.size(), "every zone is listed here")
	for id in expect:
		assert_eq(db.zones[id].region, expect[id], "%s is in %s" % [id, Regions.display_name(expect[id])])
	for id in [&"town", &"crossing", &"deepcut"]:
		assert_eq(db.zones[id].music_context, MusicTrackDef.Context.TOWN, "%s is a town" % id)
	for id in [&"deepcut_road", &"windsteppe", &"tidereach_shore"]:
		assert_eq(db.zones[id].music_context, MusicTrackDef.Context.EXPLORE, "%s is the open road" % id)
	var keys := SoundCatalog.new(db).keys()
	for k in [&"ambience_town", &"ambience_crossing", &"ambience_deepcut", &"ambience_deepcut_road",
			&"ambience_windsteppe", &"ambience_tidereach_shore"]:
		assert_true(keys.has(k), "%s is a sound key" % k)


func test_the_zones_have_what_the_brief_asks_for() -> void:
	var decor := func(id: StringName, kind: ZoneDecor.Kind) -> int:
		return db.zones[id].decor.filter(func(d): return d.kind == kind).size()
	var npcs := func(id: StringName) -> Array:
		return db.zones[id].npcs.map(func(n): return n.npc.id)
	var terrain := func(id: StringName, name: String) -> int:
		var z: ZoneDef = db.zones[id]
		var n := 0
		for row in z.terrain_rows:
			for c in row:
				if z.terrain_legend.get(c, "") == name:
					n += 1
		return n
	# Millbrook: a river (grey upstream), a well, houses, the healer's hut.
	assert_gt(terrain.call(&"town", "grey_water"), 20, "Millbrook: the river runs grey upstream")
	assert_gt(terrain.call(&"town", "water"), 10, "and clear below the mill pond")
	assert_eq(decor.call(&"town", ZoneDecor.Kind.WELL), 1, "a well")
	assert_gt(terrain.call(&"town", "roof_thatch"), 40, "houses")
	assert_true(npcs.call(&"town").has(&"healer_wenna"))
	# The Crossing: guild hall and board, vendors, inn, the shrine.
	for n in [&"guild_board", &"warden_dorne", &"trader_tamsin", &"apothecary_odo", &"innkeeper_bram"]:
		assert_true(npcs.call(&"crossing").has(n), "the Crossing has %s" % n)
	assert_eq(decor.call(&"crossing", ZoneDecor.Kind.SHRINE), 1, "the graveyard shrine")
	assert_false(db.zones[&"crossing"].graveyards.is_empty())
	assert_true(db.npcs[&"trader_tamsin"].sells.size() > 0 and db.npcs[&"apothecary_odo"].sells.size() > 0, "two vendors")
	# Deepcut: red canyon, mine entrance, steward, Mine Board, ore carts, the stream.
	assert_gt(terrain.call(&"deepcut", "red_rock"), 200, "red canyon walls")
	assert_gte(decor.call(&"deepcut", ZoneDecor.Kind.MINE), 1, "a mine entrance")
	assert_gte(decor.call(&"deepcut", ZoneDecor.Kind.CART), 3, "ore carts")
	assert_gt(terrain.call(&"deepcut", "grey_water"), 40, "the polluted stream")
	for n in [&"mine_board", &"steward_marl", &"foreman_brannoc"]:
		assert_true(npcs.call(&"deepcut").has(n), "Deepcut has %s" % n)
	# Windsteppe: gers, cairns, dry wells, herds, iron wolves.
	assert_gte(decor.call(&"windsteppe", ZoneDecor.Kind.GER), 6, "felt tents")
	assert_gte(decor.call(&"windsteppe", ZoneDecor.Kind.CAIRN), 5, "stone cairns")
	assert_gte(decor.call(&"windsteppe", ZoneDecor.Kind.DRY_WELL), 2, "dry wells")
	assert_gte(decor.call(&"windsteppe", ZoneDecor.Kind.ANIMAL), 6, "herds")
	var wolves: Array = db.zones[&"windsteppe"].enemy_spawns.filter(func(s): return s.enemy.id == &"iron_wolf")
	assert_gte(wolves.size(), 4, "iron wolves")
	assert_true(wolves.all(func(s): return not s.patrol.is_empty()), "that roam")
	# Height levels: every new zone has cliffs (3+ levels) and somewhere higher to stand.
	for id in [&"town", &"crossing", &"deepcut_road", &"deepcut", &"windsteppe"]:
		var grid := GridModel.from_zone(db.zones[id])
		var cliff := false
		var high := false
		for y in grid.depth:
			for x in grid.width:
				var p := Vector2i(x, y)
				if grid.is_walkable(p) and grid.height_at(p) >= 2:
					high = true
				for d in GridModel.DIRECTIONS:
					if grid.in_bounds(p + d) and grid.height_at(p) - grid.height_at(p + d) >= 3:
						cliff = true
		assert_true(cliff and high, "%s uses height: cliffs %s, high ground %s" % [id, cliff, high])


func test_the_crossing_is_the_hub() -> void:
	var links := func(id: StringName) -> Array:
		return db.zones[id].edges.map(func(e): return e.to_zone)
	assert_eq(links.call(&"crossing").size(), 3)
	for id in [&"town", &"deepcut_road", &"windsteppe"]:
		assert_true(links.call(&"crossing").has(id), "the Crossing leads to %s" % id)
	assert_eq(links.call(&"deepcut_road"), [&"crossing", &"deepcut"])
	assert_eq(links.call(&"deepcut"), [&"deepcut_road"])
	assert_eq(links.call(&"windsteppe"), [&"crossing"])
	for id in [&"greenfields", &"enemy_testing", &"crossing"]:
		assert_true(links.call(&"town").has(id), "Millbrook still leads to %s" % id)


func test_every_linked_edge_leads_there_and_back() -> void:
	var h := _hero("Walker")
	for z: ZoneDef in db.zones.values():
		for edge in z.edges:
			var tiles := _edge_tiles(z, edge.side)
			assert_gte(tiles.size(), 2, "%s has a way to %s" % [z.id, edge.to_zone])
			var from: Vector2i = tiles[tiles.size() / 2]
			world.move_hero(h.id, z.id, from)
			h.move.place(from)
			world.advance(0.1)
			world.submit(h.id, {"type": "step", "to": from + edge.side})
			world.advance(0.3)
			assert_eq(_zone_id(h), edge.to_zone, "%s %s -> %s" % [z.id, from, edge.to_zone])
			var arrived := h.tile()
			world.submit(h.id, {"type": "step", "to": arrived - edge.side})
			world.advance(0.3)
			assert_eq(_zone_id(h), z.id, "and back from %s %s to %s" % [edge.to_zone, arrived, z.id])
			assert_lte(GridModel.distance(h.tile(), from), 2, "%s: back where it left (%s, left from %s)" % [z.id, h.tile(), from])


# --- Co-op across zones -----------------------------------------------------------

func test_players_can_be_in_different_zones() -> void:
	var ann := _hero("Ann")
	var bob := _hero("Bob")
	var cara := _hero("Cara")
	# Ann takes the south gate to the Crossing, Bob the east side to Greenfields.
	var town := world.zone(&"town")
	assert_true(_walk(ann, Vector2i(9, town.grid.depth - 1)), "Ann at the south gate")
	world.submit(ann.id, {"type": "step", "to": Vector2i(9, town.grid.depth)})
	var events := world.advance(0.3)
	assert_eq(_zone_id(ann), &"crossing")
	assert_eq(ann.tile(), Vector2i(9, 0), "on the Crossing's north gate")
	assert_true(events.any(func(e): return e.type == "zone_change" and e.target == ann.id and e.to == &"crossing"))
	assert_true(_walk(bob, Vector2i(town.grid.width - 1, 9)))
	world.submit(bob.id, {"type": "step", "to": Vector2i(town.grid.width, 9)})
	world.advance(0.3)
	assert_eq(_zone_id(bob), &"greenfields")
	assert_eq(_zone_id(cara), &"town", "Cara stays home")
	# Each sees only their own zone.
	for pair in [[ann, &"crossing"], [bob, &"greenfields"], [cara, &"town"]]:
		var snap := Snapshot.capture(world.zone_of(pair[0].id), pair[0].id)
		assert_eq(snap.zone, pair[1])
		var heroes: Array = snap.actors.filter(func(d): return d.kind == Snapshot.KIND_HERO)
		assert_eq(heroes.size(), 1, "%s sees only themselves" % pair[0].display_name)
	# Events are tagged with their zone, so each client only gets its own.
	world.submit(ann.id, {"type": "face", "dir": Vector2i.DOWN})
	events = world.advance(0.2)
	for e in events:
		assert_has([&"crossing", &"greenfields", &"town", &"windsteppe", &"deepcut", &"deepcut_road",
				&"enemy_testing", &"tidereach_shore"], e.zone)
	# Ann carries on east to Deepcut while Bob comes back: zones fill and empty.
	world.move_hero(ann.id, &"crossing", Vector2i(37, 19))
	assert_true(_walk(ann, Vector2i(39, 19)))
	world.submit(ann.id, {"type": "step", "to": Vector2i(40, 19)})
	world.advance(0.3)
	assert_eq(_zone_id(ann), &"deepcut_road")
	assert_eq(ann.tile(), Vector2i(0, 10), "the road's west end (row 19 - 9)")
	world.submit(bob.id, {"type": "step", "to": Vector2i(-1, bob.tile().y)})
	world.advance(0.3)
	assert_eq(_zone_id(bob), &"town", "Bob is back in Millbrook with Cara")
	assert_eq(world.zone(&"town").heroes().size(), 2)
	assert_eq(world.zone(&"deepcut_road").heroes().size(), 1)
	assert_true(world.zone(&"crossing").heroes().is_empty())


func test_quest_progress_needs_the_party_in_the_same_zone() -> void:
	var ann := _hero("Ann")
	var bob := _hero("Bob")
	for h in [ann, bob]:
		h.level = 4
		QuestLog.accept(h, db.quests[&"act1_what_the_stone_remembers"])
	world.move_hero(ann.id, &"windsteppe", Vector2i(30, 16))
	world.move_hero(bob.id, &"crossing", Vector2i(17, 20))
	var steppe := world.zone(&"windsteppe")
	var wolf: Enemy = steppe.add_enemy(db.enemies[&"iron_wolf"], steppe.find_free_tile_near(ann.tile() + Vector2i(2, 0)))
	wolf.threat.add(ann.id, 1.0)
	var hits: Array[Dictionary] = []
	AbilityResolver.deal_damage(steppe.ctx, ann, wolf, &"S01", 9999.0, false, hits)
	steppe._emit_resolved(hits)
	var q: QuestDef = db.quests[&"act1_what_the_stone_remembers"]
	assert_eq(QuestLog.progress(ann, q, 1), 1, "Ann's kill counts for Ann")
	assert_eq(QuestLog.progress(bob, q, 1), 0, "not for Bob, two zones away")


# --- Death and the shrine ------------------------------------------------------------

func test_released_heroes_respawn_at_the_crossing_shrine() -> void:
	var crossing := world.zone(&"crossing")
	var shrine: Vector2i = crossing.zone.graveyards[0]
	for zid in [&"deepcut_road", &"deepcut", &"windsteppe", &"crossing"]:
		var h := _hero("Fallen")
		var sim := world.zone(zid)
		world.move_hero(h.id, zid, sim.zone.hero_spawns[0])
		h.die()
		world.submit(h.id, {"type": "release"})
		var events := world.step()
		assert_eq(_zone_id(h), &"crossing", "died in %s: back at the Crossing" % zid)
		assert_lte(GridModel.distance(h.tile(), shrine), 1, "at the shrine")
		assert_true(h.alive)
		assert_almost_eq(h.hp, roundf(h.current_stats(world.now).hp * db.rules.release_fraction), 1.0, "at half health")
		assert_true(events.any(func(e): return e.type == "release" and e.target == h.id and e.zone == &"crossing"),
				"the release is announced in the Crossing")
		if zid != &"crossing":
			assert_true(events.any(func(e): return e.type == "zone_change" and e.target == h.id and e.to == &"crossing"))
			assert_null(sim.get_actor(h.id), "gone from %s" % zid)
		world.remove_hero(h.id)


func test_millbrook_and_greenfields_keep_their_own_graveyards() -> void:
	var h := _hero("Local")
	h.die()
	world.submit(h.id, {"type": "release"})
	world.step()
	assert_eq(_zone_id(h), &"town")
	assert_eq(h.tile(), world.zone(&"town").zone.graveyards[0], "by the healer's hut")
	world.move_hero(h.id, &"greenfields", Vector2i(2, 25))
	h.die()
	world.submit(h.id, {"type": "release"})
	world.step()
	assert_eq(_zone_id(h), &"greenfields")


func test_a_released_hero_leaves_the_fight_behind() -> void:
	var ann := _hero("Ann")
	var bob := _hero("Bob")
	for h in [ann, bob]:
		world.move_hero(h.id, &"windsteppe", Vector2i(52, 21))
	var steppe := world.zone(&"windsteppe")
	var wolf: Enemy = steppe.add_enemy(db.enemies[&"iron_wolf"], Vector2i(50, 21))
	wolf.threat.add(ann.id, 5.0)
	wolf.threat.add(bob.id, 1.0)
	ann.die()
	world.submit(ann.id, {"type": "release"})
	world.step()
	assert_eq(_zone_id(ann), &"crossing")
	assert_false(wolf.threat.ids().has(ann.id), "the wolf forgets Ann")
	assert_true(wolf.threat.ids().has(bob.id), "Bob is still in the fight on the Windsteppe")
	assert_eq(_zone_id(bob), &"windsteppe")


# --- Debug ------------------------------------------------------------------------

func test_goto_takes_you_to_any_zone() -> void:
	var h := _hero("Tester")
	world.submit(h.id, {"type": "debug", "line": "goto tidereach_shore"})
	world.step()
	assert_eq(_zone_id(h), &"tidereach_shore")
	assert_eq(h.tile(), db.zones[&"tidereach_shore"].hero_spawns[0])
	world.submit(h.id, {"type": "debug", "line": "goto nowhere"})
	var events := world.step()
	assert_eq(_zone_id(h), &"tidereach_shore")
	assert_true(events.any(func(e): return e.type == "debug" and not e.ok), "an unknown zone is refused")


# --- Music on the move ---------------------------------------------------------------

func test_music_switches_by_region_when_walking_between_regions() -> void:
	var game := Game.new()
	game.settings_path = SETTINGS
	add_child_autofree(game)
	game.start_solo(CharacterData.new_character("Listener", ContentDB.heroes[&"adventurer"]))
	var session: LocalSession = game.session
	await wait_process_frames(3)
	assert_eq(Audio.current_track.id, &"idle_draft", "Millbrook: the draft (town)")
	# The Tidereach shore (debug goto) plays the water track.
	session.send_intent({"type": "debug", "line": "goto tidereach_shore"})
	await wait_physics_frames(4)
	await wait_seconds(0.4)
	assert_eq(session.zone().id, &"tidereach_shore")
	assert_eq(Audio.region, Regions.Id.TIDEREACH)
	assert_eq(Audio.current_track.id, &"explore_tidereach", "Tidereach: its own explore music")
	await wait_seconds(1.8)
	assert_almost_eq(Audio.music_fade(), 1.0, 0.01, "faded in")
	# Walk east off the shore into the Heartland (the Enemy Testing Grounds).
	var hero := session.local_hero()
	var edge := Vector2i(session.grid().width - 1, 6)
	hero.move.place(edge)
	await wait_physics_frames(2)
	var water_player: int = Audio._active
	session.send_intent({"type": "step", "to": edge + Vector2i.RIGHT})
	await wait_physics_frames(8)
	await wait_seconds(0.4)
	assert_eq(session.zone().id, &"enemy_testing", "walked into the Heartland")
	assert_eq(Audio.current_track.id, &"idle_draft", "no Heartland explore track yet: the draft")
	assert_ne(Audio._active, water_player, "crossfading on the other player")
	assert_gt(Audio._fade[water_player], 0.0, "the water track is still fading out...")
	assert_lt(Audio._fade[water_player], 1.0)
	await wait_seconds(1.8)
	assert_almost_eq(Audio._fade[water_player], 0.0, 0.01, "...and gone")
	assert_almost_eq(Audio.music_fade(), 1.0, 0.01, "the draft is in")
	game.free()
	await wait_process_frames(1)
