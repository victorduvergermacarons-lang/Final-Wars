extends GutTest
## Quest system: accept, objectives (kill, collect, talk, reach), prerequisites,
## shared progress, turn-in rewards with a choice, saves.

const ContentDBScript := preload("res://autoload/content_db.gd")

var db
var quests := {}
var world: World
var town: WorldSim
var fields: WorldSim
var hero: Hero
var token: ItemDef


func before_all() -> void:
	db = ContentDBScript.new()


func after_all() -> void:
	db.free()


func _obj(kind: QuestObjective.Kind, fields_: Dictionary) -> QuestObjective:
	var o := QuestObjective.new()
	o.kind = kind
	for k in fields_:
		o.set(k, fields_[k])
	return o


func _quest(id: StringName, giver: StringName, objectives: Array, extra: Dictionary = {}) -> QuestDef:
	var q := QuestDef.new()
	q.id = id
	q.title = String(id)
	q.giver = giver
	var objs: Array[QuestObjective] = []
	objs.assign(objectives)
	q.objectives = objs
	for k in extra:
		q.set(k, extra[k])
	quests[id] = q
	return q


func before_each() -> void:
	quests = {}
	token = ItemDef.new()
	token.id = &"wolf_token"
	token.max_stack = 20
	_quest(&"hunt", &"rowan", [_obj(QuestObjective.Kind.KILL, {"enemy": &"wolf", "count": 2, "text": "Wolves"})],
			{"reward_xp": 60, "reward_gold": 15})
	var pick: Array[ItemDef] = [db.items[&"iron_helm"], db.items[&"swift_boots"]]
	_quest(&"tokens", &"rowan", [_obj(QuestObjective.Kind.COLLECT, {"item": token, "count": 3})],
			{"reward_choices": pick})
	var pre: Array[StringName] = [&"hunt"]
	_quest(&"report", &"rowan", [_obj(QuestObjective.Kind.TALK, {"npc": &"maren"})],
			{"prerequisites": pre, "turn_in": &"maren", "sets_world_flag": &"reported"})
	_quest(&"scout", &"maren", [_obj(QuestObjective.Kind.REACH, {"zone": &"greenfields", "tile": Vector2i(10, 20), "radius": 1})])
	world = World.new(db.zones.values(), db.rules, 1, &"town", quests)
	town = world.zone(&"town")
	fields = world.zone(&"greenfields")
	hero = world.add_saved_hero(CharacterData.new_character("Ann", db.heroes[&"adventurer"]), db)


func _npc(id: StringName) -> Npc:
	for n in town.npcs():
		if n.def.id == id:
			return n
	return null


## Puts the hero next to NPC `id` and sends `intent` (with "npc" filled in).
func _at_npc(h: Hero, id: StringName, intent: Dictionary) -> Array[Dictionary]:
	var npc := _npc(id)
	for dir in GridModel.DIRECTIONS:
		if not town.is_occupied(npc.tile() + dir) and town.grid.is_walkable(npc.tile() + dir):
			h.move.place(npc.tile() + dir)
			break
	intent.npc = npc.id
	town.submit(h.id, Intents.sanitize(intent))
	return world.step()


func _rejections(events: Array) -> Array:
	return events.filter(func(e): return e.type == "rejected").map(func(e): return e.reason)


func _types(events: Array) -> Array:
	return events.map(func(e): return e.type)


func _to_fields(h: Hero, tile: Vector2i) -> void:
	var src := world.zone_of(h.id)
	if src != fields:
		world.move_hero(h.id, &"greenfields", tile)
	h.move.place(tile)


## Kills a wolf with `credit` on its threat table (events from the death itself
## are dropped: they're emitted outside a tick).
func _kill_wolf(credit: Hero) -> Array[Dictionary]:
	var wolf: Enemy = fields.enemies().filter(func(e): return e.def.id == &"wolf" and e.alive)[0]
	wolf.threat.add(credit.id, 1.0)
	wolf.hp = 1.0
	wolf.die()
	fields._on_death(wolf)
	return fields.step()


func test_accept_requires_the_giver_in_range() -> void:
	var events := _at_npc(hero, &"maren", {"type": "accept_quest", "quest": &"hunt"})
	assert_eq(_rejections(events), ["wrong_npc"])
	events = _at_npc(hero, &"rowan", {"type": "accept_quest", "quest": &"hunt"})
	assert_has(_types(events), "quest_accepted")
	assert_eq(QuestLog.status(hero, quests[&"hunt"]), QuestLog.Status.ACTIVE)
	events = _at_npc(hero, &"rowan", {"type": "accept_quest", "quest": &"hunt"})
	assert_eq(_rejections(events), ["quest_active"])


func test_kill_objective_turn_in_pays_xp_and_gold() -> void:
	_at_npc(hero, &"rowan", {"type": "accept_quest", "quest": &"hunt"})
	_to_fields(hero, Vector2i(5, 24))
	_kill_wolf(hero)
	assert_eq(QuestLog.progress(hero, quests[&"hunt"], 0), 1)
	_kill_wolf(hero)
	assert_eq(QuestLog.status(hero, quests[&"hunt"]), QuestLog.Status.READY)
	world.move_hero(hero.id, &"town", Vector2i(9, 9))
	var gold := hero.gold
	var xp_before := hero.xp + 100 * (hero.level - 1)
	var events := _at_npc(hero, &"rowan", {"type": "turn_in_quest", "quest": &"hunt", "choice": -1})
	assert_has(_types(events), "quest_completed")
	assert_eq(hero.gold, gold + 15)
	assert_gt(hero.xp + 100 * (hero.level - 1), xp_before)
	assert_eq(QuestLog.status(hero, quests[&"hunt"]), QuestLog.Status.DONE)


func test_turn_in_before_done_is_refused() -> void:
	_at_npc(hero, &"rowan", {"type": "accept_quest", "quest": &"hunt"})
	var events := _at_npc(hero, &"rowan", {"type": "turn_in_quest", "quest": &"hunt"})
	assert_eq(_rejections(events), ["quest_not_ready"])


func test_prerequisites_chain_and_world_flag() -> void:
	var events := _at_npc(hero, &"rowan", {"type": "accept_quest", "quest": &"report"})
	assert_eq(_rejections(events), ["prerequisite"])
	hero.quest_state["hunt"] = {"state": "done"}
	assert_eq(QuestLog.npc_marker(hero, quests, &"rowan"), "!", "report and tokens are on offer")
	_at_npc(hero, &"rowan", {"type": "accept_quest", "quest": &"report"})
	events = _at_npc(hero, &"maren", {"type": "talk"})
	assert_has(_types(events), "quest_ready", "talking to Maren completes it")
	assert_eq(QuestLog.npc_marker(hero, quests, &"maren"), "?")
	events = _at_npc(hero, &"maren", {"type": "turn_in_quest", "quest": &"report"})
	assert_has(_types(events), "world_flag")
	assert_true(world.world_flags.has("reported"), "the host saves it")


func test_collect_drops_only_while_needed_and_reward_choice() -> void:
	_at_npc(hero, &"rowan", {"type": "accept_quest", "quest": &"tokens"})
	var table := LootTable.new()
	var entry := LootEntry.new()
	entry.item = token
	entry.quest_id = &"tokens"
	var entries: Array[LootEntry] = [entry]
	table.entries = entries
	var rng := RandomNumberGenerator.new()
	for i in 3:
		hero.bag.add(token, Loot.roll(table, rng, hero, quests).items.size())
	assert_eq(hero.bag.count_of(token), 3)
	assert_eq(Loot.roll(table, rng, hero, quests).items.size(), 0, "no more once you have enough")
	world.step()
	assert_eq(QuestLog.status(hero, quests[&"tokens"]), QuestLog.Status.READY)
	var events := _at_npc(hero, &"rowan", {"type": "turn_in_quest", "quest": &"tokens", "choice": -1})
	assert_eq(_rejections(events), ["choose_reward"])
	events = _at_npc(hero, &"rowan", {"type": "turn_in_quest", "quest": &"tokens", "choice": 1})
	assert_has(_types(events), "quest_completed")
	assert_eq(hero.bag.count_of(token), 0, "tokens handed over")
	assert_eq(hero.bag.count_of(db.items[&"swift_boots"]), 1, "chosen reward")


func test_full_bag_refuses_turn_in_and_keeps_everything() -> void:
	_at_npc(hero, &"rowan", {"type": "accept_quest", "quest": &"tokens"})
	hero.bag.add(token, 3)
	while hero.bag.free_slots() > 0:
		hero.bag.add(db.items[&"iron_helm"], 1)
	# Handing in the tokens frees their slot, so fill that one too: use 2 stacks.
	world.step()
	var events := _at_npc(hero, &"rowan", {"type": "turn_in_quest", "quest": &"tokens", "choice": 0})
	assert_has(_types(events), "quest_completed", "the freed token slot holds the reward")
	_at_npc(hero, &"rowan", {"type": "accept_quest", "quest": &"hunt"})
	hero.quest_state["hunt"] = {"state": "active", "progress": [2], "ready": false}
	var q2: QuestDef = quests[&"hunt"]
	var rewards: Array[ItemDef] = [db.items[&"iron_helm"]]
	q2.reward_items = rewards
	events = _at_npc(hero, &"rowan", {"type": "turn_in_quest", "quest": &"hunt"})
	assert_eq(_rejections(events), ["bag_full"])
	assert_eq(QuestLog.status(hero, q2), QuestLog.Status.READY, "still ready to hand in")


func test_kill_credit_is_shared_with_nearby_party_members() -> void:
	var friend := world.add_saved_hero(CharacterData.new_character("Bo", db.heroes[&"adventurer"]), db)
	var loner := world.add_saved_hero(CharacterData.new_character("Cy", db.heroes[&"adventurer"]), db)
	for h in [hero, friend, loner]:
		_at_npc(h, &"rowan", {"type": "accept_quest", "quest": &"hunt"})
	_to_fields(hero, Vector2i(5, 24))
	_to_fields(friend, Vector2i(6, 24))
	_to_fields(loner, Vector2i(28, 2))
	_kill_wolf(hero)
	assert_eq(QuestLog.progress(hero, quests[&"hunt"], 0), 1)
	assert_eq(QuestLog.progress(friend, quests[&"hunt"], 0), 1, "nearby party member progresses too")
	assert_eq(QuestLog.progress(loner, quests[&"hunt"], 0), 0, "far away: no credit")


func test_reach_objective() -> void:
	_at_npc(hero, &"maren", {"type": "accept_quest", "quest": &"scout"})
	_to_fields(hero, Vector2i(5, 24))
	world.step()
	assert_eq(QuestLog.status(hero, quests[&"scout"]), QuestLog.Status.ACTIVE)
	hero.move.place(Vector2i(10, 21))
	var events := world.step()
	assert_has(_types(events), "quest_ready")


func test_abandon_forgets_progress() -> void:
	_at_npc(hero, &"rowan", {"type": "accept_quest", "quest": &"hunt"})
	town.submit(hero.id, Intents.sanitize({"type": "abandon_quest", "quest": &"hunt"}))
	assert_has(_types(world.step()), "quest_abandoned")
	assert_eq(QuestLog.status(hero, quests[&"hunt"]), QuestLog.Status.AVAILABLE)


func test_save_normalizes_quest_state() -> void:
	var raw := {"hunt": {"state": "active", "progress": [1.0, 7]}, "tokens": {"state": "done"},
			"nope": {"state": "active"}, "report": "garbage"}
	var clean := QuestLog.normalize(JSON.parse_string(JSON.stringify(raw)), quests)
	assert_eq(clean.keys().size(), 2, "unknown and malformed quests dropped")
	assert_eq(clean.hunt.progress, [1])
	assert_eq(typeof(clean.hunt.progress[0]), TYPE_INT)
	assert_eq(clean.tokens, {"state": "done"})


func test_intents_sanitize_quests() -> void:
	assert_eq(Intents.sanitize({"type": "accept_quest", "quest": "hunt", "npc": 3}),
			{"type": "accept_quest", "quest": &"hunt", "npc": 3})
	assert_eq(Intents.sanitize({"type": "accept_quest", "quest": "hunt"}), {}, "needs the npc")
	assert_eq(Intents.sanitize({"type": "abandon_quest", "quest": 5}), {})
	assert_eq(Intents.sanitize({"type": "turn_in_quest", "quest": "hunt", "npc": 3, "choice": 1}).choice, 1)
