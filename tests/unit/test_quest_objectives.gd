extends GutTest
## Act I quest rules on a small flat map: prerequisites, every objective kind
## (talk, kill, reach, interact, deliver, investigate, escort), escort failure and
## restarting from the giver, items handed over on accept, and co-op (a quest
## offered to the whole party, progress shared with party members nearby, each
## hero's progress saved with that hero).

var world: WorldSim
var ann: Hero
var bob: Hero
var guide: NpcDef
var board: NpcDef
var lever: NpcDef
var cart: NpcDef
var foreman: NpcDef
var letter: ItemDef

const CART_HOME := Vector2i(4, 10)
const CART_PATH: Array[Vector2i] = [Vector2i(8, 10), Vector2i(14, 10)]


func _npc_def(id: StringName, kind: NpcDef.Kind, hp: float = 0.0) -> NpcDef:
	var d := NpcDef.new()
	d.id = id
	d.display_name = String(id).capitalize()
	d.kind = kind
	d.max_hp = hp
	return d


func _spawn(def: NpcDef, tile: Vector2i) -> NpcSpawn:
	var s := NpcSpawn.new()
	s.npc = def
	s.tile = tile
	return s


func _obj(kind: QuestObjective.Kind, fields: Dictionary) -> QuestObjective:
	var o := QuestObjective.new()
	o.kind = kind
	for k in fields:
		o.set(k, fields[k])
	return o


func _quest(id: StringName, objectives: Array, extra: Dictionary = {}) -> QuestDef:
	var q := QuestDef.new()
	q.id = id
	q.title = String(id)
	q.giver = &"guide"
	var objs: Array[QuestObjective] = []
	objs.assign(objectives)
	q.objectives = objs
	for k in extra:
		q.set(k, extra[k])
	world.quests[id] = q
	return q


func _hero(at: Vector2i) -> Hero:
	var hd := HeroDef.new()
	hd.base_stats = StatBlock.make({Stat.Id.HP: 500, Stat.Id.JUMP: 2})
	var h := world.add_hero(hd)
	h.move.place(at)
	return h


func before_each() -> void:
	guide = _npc_def(&"guide", NpcDef.Kind.PERSON)
	board = _npc_def(&"guild_board", NpcDef.Kind.BOARD)
	lever = _npc_def(&"old_lever", NpcDef.Kind.OBJECT)
	cart = _npc_def(&"ore_cart", NpcDef.Kind.CARAVAN, 40.0)
	foreman = _npc_def(&"foreman", NpcDef.Kind.PERSON)
	letter = ItemDef.new()
	letter.id = &"sealed_letter"
	letter.quest_item = true
	var zone := ZoneDef.new()
	zone.id = &"plain"
	var rows: PackedStringArray = []
	var walk: PackedStringArray = []
	for y in 30:
		rows.append("0".repeat(30))
		walk.append(".".repeat(30))
	zone.height_rows = rows
	zone.walk_rows = walk
	zone.graveyards = [Vector2i(0, 0)]
	zone.hero_spawns = [Vector2i(0, 0)]
	var spawns: Array[NpcSpawn] = [_spawn(guide, Vector2i(2, 2)), _spawn(board, Vector2i(6, 2)),
			_spawn(lever, Vector2i(20, 20)), _spawn(cart, CART_HOME), _spawn(foreman, Vector2i(25, 5))]
	zone.npcs = spawns
	world = WorldSim.new(zone, ContentDB.rules, 5)
	world.quests = {}
	ann = _hero(Vector2i(2, 3))
	bob = _hero(Vector2i(3, 3))


func _npc(def: NpcDef) -> Npc:
	for n in world.npcs():
		if n.def == def:
			return n
	return null


func _run(seconds: float) -> Array:
	var events := []
	for i in roundi(seconds / world.rules.tick_seconds):
		events.append_array(world.step())
	return events


func _send(h: Hero, intent: Dictionary) -> Array:
	world.submit(h.id, intent)
	return world.step()


func _rejected(events: Array, h: Hero) -> String:
	for e in events:
		if e.type == "rejected" and e.target == h.id:
			return e.reason
	return ""


func _talk(h: Hero, def: NpcDef) -> Array:
	var npc := _npc(def)
	h.move.place(npc.tile() + Vector2i(0, 1))
	return _send(h, {"type": "talk", "npc": npc.id})


func _accept(h: Hero, q: QuestDef) -> Array:
	var giver := _npc(guide) if q.giver == &"guide" else _npc(board)
	h.move.place(giver.tile() + Vector2i(0, 1))
	return _send(h, {"type": "accept_quest", "npc": giver.id, "quest": q.id})


# --- Prerequisites ------------------------------------------------------------

func test_prerequisites_and_level_lock_a_quest_until_met() -> void:
	var first := _quest(&"first", [_obj(QuestObjective.Kind.TALK, {"npc": &"foreman"})])
	var pre: Array[StringName] = [&"first"]
	var second := _quest(&"second", [_obj(QuestObjective.Kind.TALK, {"npc": &"guide"})],
			{"prerequisites": pre, "min_level": 2})
	assert_eq(QuestLog.status(ann, second), QuestLog.Status.UNAVAILABLE)
	assert_eq(_rejected(_accept(ann, second), ann), "prerequisite")
	assert_eq(QuestLog.npc_marker(ann, world.quests, &"guide"), "!", "the first one is offered")
	_accept(ann, first)
	_talk(ann, foreman)
	assert_eq(QuestLog.npc_marker(ann, world.quests, &"guide"), "?", "ready to hand in")
	ann.move.place(_npc(guide).tile() + Vector2i(0, 1))
	_send(ann, {"type": "turn_in_quest", "npc": _npc(guide).id, "quest": &"first", "choice": -1})
	assert_true(QuestLog.is_done(ann, &"first"))
	assert_eq(QuestLog.can_accept(ann, second), "level_too_low", "still needs level 2")
	ann.level = 2
	assert_eq(QuestLog.status(ann, second), QuestLog.Status.AVAILABLE)
	assert_eq(_rejected(_accept(ann, second), ann), "")


# --- Objective kinds ------------------------------------------------------------

func test_talk_objective() -> void:
	var q := _quest(&"talk", [_obj(QuestObjective.Kind.TALK, {"npc": &"foreman"})])
	_accept(ann, q)
	assert_eq(QuestLog.status(ann, q), QuestLog.Status.ACTIVE)
	_talk(ann, foreman)
	assert_eq(QuestLog.status(ann, q), QuestLog.Status.READY)


func test_kill_objective() -> void:
	var q := _quest(&"kill", [_obj(QuestObjective.Kind.KILL, {"enemy": &"wolf", "count": 2})])
	_accept(ann, q)
	for i in 2:
		var wolf := world.add_enemy(ContentDB.enemies[&"wolf"], Vector2i(10 + i * 3, 3))
		wolf.threat.add(ann.id, 1.0)
		wolf.hp = 1.0
		var events: Array[Dictionary] = []
		AbilityResolver.deal_damage(world.ctx, ann, wolf, &"test", 10.0, false, events)
		world._emit_resolved(events)
	assert_eq(QuestLog.progress(ann, q, 0), 2)
	assert_eq(QuestLog.status(ann, q), QuestLog.Status.READY)


func test_reach_objective() -> void:
	var q := _quest(&"reach", [_obj(QuestObjective.Kind.REACH, {"zone": &"plain", "tile": Vector2i(15, 15), "radius": 1})])
	_accept(ann, q)
	ann.move.place(Vector2i(15, 17))
	world.step()
	assert_eq(QuestLog.status(ann, q), QuestLog.Status.ACTIVE, "2 tiles away is not there")
	ann.move.place(Vector2i(15, 16))
	world.step()
	assert_eq(QuestLog.status(ann, q), QuestLog.Status.READY)


func test_quest_boards_give_quests() -> void:
	var q := _quest(&"posted", [_obj(QuestObjective.Kind.TALK, {"npc": &"foreman"})], {"giver": &"guild_board"})
	assert_eq(QuestLog.npc_marker(ann, world.quests, &"guild_board"), "!")
	_accept(ann, q)
	assert_true(QuestLog.is_active(ann, &"posted"))


func test_interact_with_an_object() -> void:
	var q := _quest(&"lever", [_obj(QuestObjective.Kind.INTERACT, {"npc": &"old_lever"})])
	_accept(ann, q)
	var lever_npc := _npc(lever)
	ann.move.place(lever_npc.tile() + Vector2i(0, 4))
	assert_eq(_rejected(_send(ann, {"type": "talk", "npc": lever_npc.id}), ann), "too_far")
	_talk(ann, lever)
	assert_eq(QuestLog.status(ann, q), QuestLog.Status.READY)


func test_deliver_hands_over_the_item_given_on_accept() -> void:
	var given: Array[ItemDef] = [letter]
	var q := _quest(&"letter", [_obj(QuestObjective.Kind.DELIVER, {"npc": &"foreman", "item": letter})],
			{"given_items": given})
	_accept(ann, q)
	assert_eq(ann.bag.count_of(letter), 1, "the giver hands the letter over")
	_talk(ann, guide) # the wrong person
	assert_eq(QuestLog.progress(ann, q, 0), 0)
	var events := _talk(ann, foreman)
	assert_true(events.any(func(e): return e.type == "delivered" and e.target == ann.id))
	assert_eq(ann.bag.count_of(letter), 0, "delivered")
	assert_eq(QuestLog.status(ann, q), QuestLog.Status.READY)


func test_deliver_without_the_item_does_nothing_and_abandon_takes_it_back() -> void:
	var given: Array[ItemDef] = [letter]
	var q := _quest(&"letter", [_obj(QuestObjective.Kind.DELIVER, {"npc": &"foreman", "item": letter})],
			{"given_items": given})
	_accept(ann, q)
	ann.bag.remove_item(letter, 1) # lost it
	_talk(ann, foreman)
	assert_eq(QuestLog.progress(ann, q, 0), 0)
	ann.bag.add(letter, 1)
	_send(ann, {"type": "abandon_quest", "quest": &"letter"})
	assert_eq(ann.bag.count_of(letter), 0, "abandoning takes the letter back")


func test_investigate_every_marked_spot() -> void:
	var spots: Array[Vector2i] = [Vector2i(10, 10), Vector2i(12, 14), Vector2i(18, 8)]
	var q := _quest(&"ash", [_obj(QuestObjective.Kind.INVESTIGATE, {"zone": &"plain", "spots": spots})])
	_accept(ann, q)
	assert_eq(q.objectives[0].needed(), 3)
	ann.move.place(Vector2i(10, 13))
	assert_eq(_rejected(_send(ann, {"type": "examine", "tile": Vector2i(10, 10)}), ann), "too_far")
	ann.move.place(Vector2i(10, 11))
	var events := _send(ann, {"type": "examine", "tile": Vector2i(10, 10)})
	assert_true(events.any(func(e): return e.type == "examined" and e.spot == 0))
	assert_eq(QuestLog.progress(ann, q, 0), 1)
	assert_eq(_rejected(_send(ann, {"type": "examine", "tile": Vector2i(10, 10)}), ann), "nothing_here",
			"the same spot counts once")
	for s in [1, 2]:
		ann.move.place(spots[s] + Vector2i(1, 0))
		_send(ann, {"type": "examine", "tile": spots[s]})
	assert_eq(QuestLog.status(ann, q), QuestLog.Status.READY)
	assert_eq(QuestLog.found_spots(ann, q, 0), [0, 1, 2])


# --- Escort ------------------------------------------------------------------------

func _escort_quest() -> QuestDef:
	return _quest(&"convoy", [_obj(QuestObjective.Kind.ESCORT, {"npc": &"ore_cart", "zone": &"plain", "path": CART_PATH})])


func test_escort_walks_its_path_waits_for_the_party_and_completes() -> void:
	var q := _escort_quest()
	_accept(ann, q)
	var cart_npc := _npc(cart)
	_talk(ann, cart)
	assert_true(cart_npc.escorting, "talking to the cart sets it off")
	assert_eq(cart_npc.team, Actor.Team.HEROES, "on the heroes' side while escorted")
	assert_true(AbilityResolver._is_valid_target(ann, ContentDB.abilities[&"W01"], cart_npc), "heroes can heal it")
	ann.move.place(Vector2i(25, 25)) # far behind
	_run(1.0) # finishes the step it started
	var waiting_at := cart_npc.tile()
	_run(3.0)
	assert_eq(cart_npc.tile(), waiting_at, "it waits for the party")
	ann.move.place(waiting_at + Vector2i(0, 2))
	bob.move.place(waiting_at + Vector2i(1, 2))
	var arrived := false
	for i in 400:
		var events := world.step()
		ann.move.place(cart_npc.tile() + Vector2i(0, 2)) # following it
		if events.any(func(e): return e.type == "escort_arrived"):
			arrived = true
			break
	assert_true(arrived, "reached the end of its path")
	assert_eq(cart_npc.tile(), CART_PATH[-1])
	assert_eq(QuestLog.status(ann, q), QuestLog.Status.READY)
	assert_false(cart_npc.escorting)
	_run(WorldSim.ESCORT_HOME_SECONDS + 0.5)
	assert_eq(cart_npc.tile(), CART_HOME, "then it goes back to where it started")


func test_escort_death_fails_the_quest_and_it_restarts_from_the_giver() -> void:
	var q := _escort_quest()
	_accept(ann, q)
	_send(bob, {"type": "accept_shared_quest", "quest": &"convoy"})
	assert_true(QuestLog.is_active(bob, &"convoy"))
	var cart_npc := _npc(cart)
	_talk(ann, cart)
	ann.move.place(CART_HOME + Vector2i(-3, 0))
	# A wolf on the road spots the cart and goes for it.
	world.add_enemy(ContentDB.enemies[&"wolf"], CART_HOME + Vector2i(3, 0))
	var failed := []
	for i in 1200:
		for e in world.step():
			if e.type == "quest_failed":
				failed.append(e.target)
		if not cart_npc.alive:
			break
	assert_false(cart_npc.alive, "the wolf killed the cart")
	assert_true(failed.has(ann.id) and failed.has(bob.id), "the quest fails for the whole party")
	assert_eq(QuestLog.status(ann, q), QuestLog.Status.FAILED)
	assert_eq(QuestLog.npc_marker(ann, world.quests, &"guide"), "!", "the giver offers it again")
	_run(WorldSim.ESCORT_RESPAWN_SECONDS + 0.5)
	assert_true(cart_npc.alive, "the cart is back")
	assert_eq(cart_npc.tile(), CART_HOME)
	assert_almost_eq(cart_npc.hp, 40.0, 0.01)
	assert_false(cart_npc.escorting)
	assert_eq(_rejected(_accept(ann, q), ann), "", "restarted from the giver")
	assert_eq(QuestLog.status(ann, q), QuestLog.Status.ACTIVE)
	assert_eq(QuestLog.progress(ann, q, 0), 0, "fresh progress")


# --- Co-op ----------------------------------------------------------------------------

func test_accepting_offers_the_quest_to_the_rest_of_the_party() -> void:
	var q := _quest(&"shared", [_obj(QuestObjective.Kind.TALK, {"npc": &"foreman"})])
	var pre: Array[StringName] = [&"shared"]
	_quest(&"later", [_obj(QuestObjective.Kind.TALK, {"npc": &"foreman"})], {"prerequisites": pre})
	assert_eq(_rejected(_send(bob, {"type": "accept_shared_quest", "quest": &"shared"}), bob), "not_shared",
			"nobody has it yet")
	var events := _accept(ann, q)
	assert_true(events.any(func(e): return e.type == "quest_shared" and e.target == bob.id and e.source == ann.id),
			"Bob gets the prompt")
	bob.move.place(Vector2i(28, 28)) # far from the giver: the prompt works anywhere in the zone
	_send(bob, {"type": "accept_shared_quest", "quest": &"shared"})
	assert_true(QuestLog.is_active(bob, &"shared"))
	_give_active(ann, "later")
	assert_eq(_rejected(_send(bob, {"type": "accept_shared_quest", "quest": &"later"}), bob), "prerequisite",
			"a shared quest still needs its prerequisites")


func _give_active(h: Hero, id: String) -> void:
	h.quest_state[id] = {"state": "active", "progress": [0], "ready": false, "found": {}}


func test_progress_counts_for_party_members_nearby_and_is_saved_per_hero() -> void:
	var spots: Array[Vector2i] = [Vector2i(10, 10), Vector2i(20, 20)]
	var q := _quest(&"together", [_obj(QuestObjective.Kind.TALK, {"npc": &"foreman"}),
			_obj(QuestObjective.Kind.INVESTIGATE, {"zone": &"plain", "spots": spots})])
	_accept(ann, q)
	_send(bob, {"type": "accept_shared_quest", "quest": &"together"})
	var cara := _hero(Vector2i(0, 29)) # joins later, not on the quest
	bob.move.place(_npc(foreman).tile() + Vector2i(1, 1))
	_talk(ann, foreman)
	assert_eq(QuestLog.progress(bob, q, 0), 1, "Bob was nearby: counts for him too")
	assert_false(cara.quest_state.has("together"), "not on the quest: nothing")
	bob.move.place(Vector2i(29, 0)) # far away now
	ann.move.place(Vector2i(10, 11))
	_send(ann, {"type": "examine", "tile": Vector2i(10, 10)})
	assert_eq(QuestLog.progress(ann, q, 1), 1)
	assert_eq(QuestLog.progress(bob, q, 1), 0, "too far to count")
	# Each hero's progress is saved with that hero.
	var saved_ann := CharacterData.capture(ann)
	var saved_bob := CharacterData.capture(bob)
	var ann_state := QuestLog.normalize(JSON.parse_string(JSON.stringify(saved_ann.quests)), world.quests)
	var bob_state := QuestLog.normalize(JSON.parse_string(JSON.stringify(saved_bob.quests)), world.quests)
	assert_eq(ann_state.together.progress, [1, 1])
	assert_eq(ann_state.together.found, {"1": [0]})
	assert_eq(bob_state.together.progress, [1, 0])


func test_failed_quests_survive_a_save() -> void:
	var q := _escort_quest()
	_accept(ann, q)
	QuestLog.fail(ann, q)
	var st := QuestLog.normalize(JSON.parse_string(JSON.stringify(ann.quest_state)), world.quests)
	assert_eq(st.convoy, {"state": "failed"})


func test_given_items_need_room_in_the_bag() -> void:
	var given: Array[ItemDef] = [letter]
	var q := _quest(&"letter", [_obj(QuestObjective.Kind.DELIVER, {"npc": &"foreman", "item": letter})],
			{"given_items": given})
	var junk := ItemDef.new()
	junk.id = &"junk"
	while ann.bag.add(junk, 1) == 0:
		pass
	assert_eq(_rejected(_accept(ann, q), ann), "bag_full")
	assert_false(QuestLog.is_active(ann, &"letter"))


func test_new_intents_are_sanitized() -> void:
	assert_eq(Intents.sanitize({"type": "examine", "tile": Vector2i(1, 2)}), {"type": "examine", "tile": Vector2i(1, 2)})
	assert_eq(Intents.sanitize({"type": "examine", "tile": "x"}), {})
	assert_eq(Intents.sanitize({"type": "accept_shared_quest", "quest": "a"}), {"type": "accept_shared_quest", "quest": &"a"})
	assert_eq(Intents.sanitize({"type": "accept_shared_quest"}), {})
