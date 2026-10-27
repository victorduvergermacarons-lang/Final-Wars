extends GutTest
## Act I on the shipped content: where everything stands, and the whole main
## chain played by a party of two on the host World with real intents (the second
## hero joins through the co-op prompt), across the zones: the Guild Board's
## summons (the Crossing), the scorched places (Greenfields), the Ember Hand's writ
## (to Deepcut), the ore caravan escort (Deepcut), the Vael stone (Windsteppe).

const ContentDBScript := preload("res://autoload/content_db.gd")
const MAIN := [&"act1_guild_summons", &"act1_ash_on_the_road", &"act1_ember_writ", &"act1_ore_for_millbrook",
		&"act1_what_the_stone_remembers"]

var db
var world: World
var ann: Hero
var bob: Hero


func before_all() -> void:
	db = ContentDBScript.new()


func after_all() -> void:
	db.free()


func before_each() -> void:
	world = World.new(db.zones.values(), db.rules, 4, &"town", db.quests)
	ann = world.add_saved_hero(CharacterData.new_character("Ann", db.heroes[&"adventurer"]), db)
	bob = world.add_saved_hero(CharacterData.new_character("Bob", db.heroes[&"adventurer"]), db)
	for h in [ann, bob]:
		h.level = 6 # sturdy enough for the wolves on the way


func _npc(zone_id: StringName, npc_id: StringName) -> Npc:
	for n in world.zone(zone_id).npcs():
		if n.def.id == npc_id:
			return n
	return null


## Puts `h` (and its partner, close behind) beside NPC `npc_id`, in its zone.
func _go_to(h: Hero, zone_id: StringName, npc_id: StringName) -> Npc:
	var npc := _npc(zone_id, npc_id)
	_place(h, zone_id, npc.tile())
	return npc


func _place(h: Hero, zone_id: StringName, near: Vector2i) -> void:
	if world.zone_of(h.id).zone.id != zone_id:
		world.move_hero(h.id, zone_id, near)
	var sim := world.zone(zone_id)
	h.move.place(sim.find_free_tile_near(near) if sim.is_occupied(near, h) or not sim.grid.is_walkable(near) else near)


func _send(h: Hero, intent: Dictionary) -> Array[Dictionary]:
	world.submit(h.id, Intents.sanitize(intent))
	return world.step()


func _talk(h: Hero, zone_id: StringName, npc_id: StringName) -> Array[Dictionary]:
	var npc := _go_to(h, zone_id, npc_id)
	return _send(h, {"type": "talk", "npc": npc.id})


func _accept(h: Hero, quest: StringName) -> Array[Dictionary]:
	var def: QuestDef = db.quests[quest]
	var zone_id := _zone_of_npc(def.giver)
	var npc := _go_to(h, zone_id, def.giver)
	return _send(h, {"type": "accept_quest", "npc": npc.id, "quest": quest})


func _turn_in(h: Hero, quest: StringName) -> Array[Dictionary]:
	var def: QuestDef = db.quests[quest]
	var npc := _go_to(h, _zone_of_npc(def.turn_in_npc()), def.turn_in_npc())
	return _send(h, {"type": "turn_in_quest", "npc": npc.id, "quest": quest, "choice": -1})


func _zone_of_npc(npc_id: StringName) -> StringName:
	for zid in world.zone_ids():
		if _npc(zid, npc_id) != null:
			return zid
	return &""


func _rejected(events: Array, h: Hero) -> String:
	for e in events:
		if e.type == "rejected" and e.target == h.id:
			return e.reason
	return ""


# --- Placement ------------------------------------------------------------------

func test_act1_npcs_spots_and_routes_are_usable() -> void:
	for id in [&"guild_board", &"warden_dorne", &"sabra_venn", &"seer_ilyth", &"mine_board", &"foreman_brannoc",
			&"ore_caravan", &"collapsed_shaft", &"vael_stone"]:
		var zid := _zone_of_npc(id)
		assert_ne(zid, &"", "%s is placed somewhere" % id)
		var sim := world.zone(zid)
		var npc := _npc(zid, id)
		assert_true(sim.grid.is_walkable(npc.tile()), "%s stands on walkable ground" % id)
		var free := GridModel.DIRECTIONS.any(func(d): return sim.grid.is_walkable(npc.tile() + d) and not sim.is_occupied(npc.tile() + d))
		assert_true(free, "%s can be reached" % id)
	assert_eq(db.npcs[&"guild_board"].kind, NpcDef.Kind.BOARD)
	assert_eq(db.npcs[&"mine_board"].kind, NpcDef.Kind.BOARD)
	assert_eq(db.npcs[&"ore_caravan"].kind, NpcDef.Kind.CARAVAN)
	for q in db.quests.values():
		for o in q.objectives:
			if o.kind == QuestObjective.Kind.INVESTIGATE:
				for s in o.spots:
					assert_true(world.zone(o.zone).grid.is_walkable(s), "%s spot %s is on walkable ground" % [q.id, s])
			if o.kind == QuestObjective.Kind.ESCORT:
				var sim := world.zone(o.zone)
				var cart := _npc(o.zone, o.npc)
				var from := cart.tile()
				for p in o.path:
					var path := Pathfinder.find_path(sim.grid, from, p, 1, {}, -1, 20000)
					assert_false(path.is_empty(), "%s: the caravan can walk from %s to %s" % [q.id, from, p])
					from = p


func test_act1_quests_are_main_and_side_with_areas_and_lines() -> void:
	for id in MAIN:
		var q: QuestDef = db.quests[id]
		assert_true(q.is_main(), "%s is a main quest" % id)
		assert_ne(q.area, "")
		assert_true(db.dialogue.has(q.line_id("offer")))
	for id in [&"side_bandits_on_the_ore_road", &"side_collapsed_shaft", &"side_guild_patrol"]:
		assert_false(db.quests[id].is_main())
	for i in range(1, MAIN.size()):
		assert_true(db.quests[MAIN[i]].prerequisites.has(MAIN[i - 1]), "%s follows %s" % [MAIN[i], MAIN[i - 1]])
	assert_eq(db.validate(), PackedStringArray(), "content and dialogue file check out")


# --- The whole main chain, in co-op ---------------------------------------------

func test_act1_main_chain_in_coop() -> void:
	# 1. The Guild Board's summons; Bob joins through the prompt.
	_place(bob, &"crossing", Vector2i(17, 20)) # quest offers reach the party in the same zone
	var events := _accept(ann, MAIN[0])
	assert_true(events.any(func(e): return e.type == "quest_shared" and e.target == bob.id), "Bob is offered it")
	_send(bob, {"type": "accept_shared_quest", "quest": MAIN[0]})
	_place(bob, &"crossing", ann.tile())
	_talk(ann, &"crossing", &"warden_dorne")
	for h in [ann, bob]:
		assert_eq(QuestLog.status(h, db.quests[MAIN[0]]), QuestLog.Status.READY, "%s: Dorne found" % h.display_name)
		_turn_in(h, MAIN[0])
		assert_true(QuestLog.is_done(h, MAIN[0]))

	# 2. Ash on the East Road: three scorched places, found together.
	_accept(ann, MAIN[1])
	_send(bob, {"type": "accept_shared_quest", "quest": MAIN[1]})
	var spots: Array = db.quests[MAIN[1]].objectives[0].spots
	for s in spots:
		_place(ann, &"greenfields", s + Vector2i(0, 1))
		_place(bob, &"greenfields", s + Vector2i(1, 1))
		events = _send(ann, {"type": "examine", "tile": s})
		assert_true(events.any(func(e): return e.type == "examined"), "examined %s" % s)
	for h in [ann, bob]:
		assert_eq(QuestLog.status(h, db.quests[MAIN[1]]), QuestLog.Status.READY, "%s saw all three" % h.display_name)
		_turn_in(h, MAIN[1])

	# 3. The Ember Hand's writ, handed over to the Bedrun foreman.
	for h in [ann, bob]:
		_accept(h, MAIN[2])
		assert_eq(h.bag.count_of(db.items[&"sealed_writ"]), 1, "Sabra hands %s the writ" % h.display_name)
	_place(bob, &"deepcut", _npc(&"deepcut", &"foreman_brannoc").tile())
	events = _talk(ann, &"deepcut", &"foreman_brannoc")
	assert_true(events.any(func(e): return e.type == "delivered"))
	for h in [ann, bob]:
		assert_eq(h.bag.count_of(db.items[&"sealed_writ"]), 0, "%s's writ is delivered" % h.display_name)
		_turn_in(h, MAIN[2])
		assert_true(QuestLog.is_done(h, MAIN[2]))

	# 4. Ore for Millbrook: the party walks the caravan to Deepcut's canyon gate.
	for h in [ann, bob]:
		_accept(h, MAIN[3])
	var deepcut := world.zone(&"deepcut")
	for enemy in deepcut.enemies(): # a quiet road (the escort's dangers are tested elsewhere)
		enemy.respawn_at = 1.0e9
		enemy.die()
		enemy.state = Enemy.State.DEAD
	var cart := _npc(&"deepcut", &"ore_caravan")
	_talk(ann, &"deepcut", &"ore_caravan")
	assert_true(cart.escorting, "it sets off")
	var arrived := false
	for i in 3000:
		for h in [ann, bob]:
			_place(h, &"deepcut", cart.tile() + Vector2i(1, 2)) # following it
		if world.step().any(func(e): return e.type == "escort_arrived"):
			arrived = true
			break
	assert_true(arrived, "the caravan reaches the canyon gate (at %s)" % cart.tile())
	for h in [ann, bob]:
		assert_eq(QuestLog.status(h, db.quests[MAIN[3]]), QuestLog.Status.READY)
		_turn_in(h, MAIN[3])
		assert_true(QuestLog.is_done(h, MAIN[3]), "handed in to Dorne at the Crossing")

	# 5. What the Stone Remembers: the stone on the Windsteppe, then three iron wolves.
	for h in [ann, bob]:
		_accept(h, MAIN[4])
	_place(bob, &"windsteppe", _npc(&"windsteppe", &"vael_stone").tile())
	_talk(ann, &"windsteppe", &"vael_stone")
	var q5: QuestDef = db.quests[MAIN[4]]
	var steppe := world.zone(&"windsteppe")
	assert_eq(QuestLog.progress(bob, q5, 0), 1, "the stone counts for Bob beside it")
	for i in 3:
		var wolf: Enemy = steppe.add_enemy(db.enemies[&"iron_wolf"], steppe.find_free_tile_near(ann.tile() + Vector2i(2, 0)))
		wolf.threat.add(ann.id, 1.0)
		var hits: Array[Dictionary] = []
		AbilityResolver.deal_damage(steppe.ctx, ann, wolf, &"S01", 9999.0, false, hits)
		steppe._emit_resolved(hits)
	for h in [ann, bob]:
		assert_eq(QuestLog.status(h, q5), QuestLog.Status.READY, "%s: stone touched and wolves gone" % h.display_name)
	events = _turn_in(ann, MAIN[4])
	assert_true(events.any(func(e): return e.type == "world_flag" and e.flag == &"act1_complete"), "end of Act I")
	_turn_in(bob, MAIN[4])
	assert_true(QuestLog.is_done(bob, MAIN[4]))
