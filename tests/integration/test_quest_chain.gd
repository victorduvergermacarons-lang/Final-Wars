extends GutTest
## Plays Captain Rowan's 3-quest chain on the shipped content, end to end on the
## host World: accept, kill/reach credit, hand-ins, item choice, world event.

const ContentDBScript := preload("res://autoload/content_db.gd")

var db
var world: World
var hero: Hero


func before_all() -> void:
	db = ContentDBScript.new()


func after_all() -> void:
	db.free()


func before_each() -> void:
	world = World.new(db.zones.values(), db.rules, 3, &"town", db.quests)
	hero = world.add_saved_hero(CharacterData.new_character("Tess", db.heroes[&"adventurer"]), db)


func _send(intent: Dictionary) -> Array[Dictionary]:
	world.submit(hero.id, Intents.sanitize(intent))
	return world.step()


func _talk_to(npc_id: StringName, intent: Dictionary) -> Array[Dictionary]:
	if world.zone_of(hero.id).zone.id != &"town":
		world.move_hero(hero.id, &"town", Vector2i(9, 9))
	var town := world.zone(&"town")
	var npc: Npc = town.npcs().filter(func(n): return n.def.id == npc_id)[0]
	for dir in GridModel.DIRECTIONS:
		var t := npc.tile() + dir
		if town.grid.is_walkable(t) and not town.is_occupied(t, hero):
			hero.move.place(t)
			break
	intent.npc = npc.id
	return _send(intent)


func _kill(enemy_id: StringName, n: int) -> void:
	for i in n:
		var fields := world.zone(&"greenfields")
		var enemy: Enemy = fields.enemies().filter(func(e): return e.def.id == enemy_id and e.alive)[0]
		if world.zone_of(hero.id) != fields:
			world.move_hero(hero.id, &"greenfields", Vector2i(2, 25))
		enemy.threat.add(hero.id, 1.0)
		enemy.die()
		fields._on_death(enemy)
		world.step()


func _rejected(events: Array) -> Array:
	return events.filter(func(e): return e.type == "rejected").map(func(e): return e.reason)


func test_rowans_chain_end_to_end() -> void:
	assert_eq(QuestLog.npc_marker(hero, db.quests, &"rowan"), "!")
	assert_eq(_rejected(_talk_to(&"rowan", {"type": "accept_quest", "quest": &"bandit_camp"})), ["prerequisite"])

	_talk_to(&"rowan", {"type": "accept_quest", "quest": &"wolves_at_the_gate"})
	_kill(&"wolf", 4)
	assert_eq(QuestLog.npc_marker(hero, db.quests, &"rowan"), "?")
	_talk_to(&"rowan", {"type": "turn_in_quest", "quest": &"wolves_at_the_gate"})
	assert_true(QuestLog.is_done(hero, &"wolves_at_the_gate"))
	assert_eq(hero.level, 3, "4 wolves + quest XP: level 3")

	_talk_to(&"rowan", {"type": "accept_quest", "quest": &"bandit_camp"})
	_kill(&"bandit_brute", 2)
	assert_eq(QuestLog.status(hero, db.quests[&"bandit_camp"]), QuestLog.Status.ACTIVE, "camp not found yet")
	hero.move.place(Vector2i(22, 18))
	world.step()
	assert_eq(QuestLog.status(hero, db.quests[&"bandit_camp"]), QuestLog.Status.READY)
	_talk_to(&"rowan", {"type": "turn_in_quest", "quest": &"bandit_camp"})

	_talk_to(&"rowan", {"type": "accept_quest", "quest": &"beast_of_greenfields"})
	_kill(&"old_grizzlehide", 1)
	assert_eq(_rejected(_talk_to(&"rowan", {"type": "turn_in_quest", "quest": &"beast_of_greenfields"})),
			["choose_reward"])
	var events := _talk_to(&"rowan", {"type": "turn_in_quest", "quest": &"beast_of_greenfields", "choice": 0})
	assert_true(events.any(func(e): return e.type == "world_flag" and e.flag == &"grizzlehide_slain"))
	assert_eq(hero.bag.count_of(db.items[&"greataxe"]), 1, "chose the Greataxe")
	assert_true(world.world_flags.has("grizzlehide_slain"))
	assert_eq(QuestLog.npc_marker(hero, db.quests, &"rowan"), "", "chain finished")


func test_goblin_fetishes_drop_only_on_the_quest() -> void:
	var fetish: ItemDef = db.items[&"goblin_fetish"]
	_kill(&"goblin_shaman", 2)
	assert_eq(hero.bag.count_of(fetish), 0, "no fetishes without the quest")
	world.advance(31.0) # respawn
	hero.level = 2
	_talk_to(&"maren", {"type": "accept_quest", "quest": &"goblin_fetishes"})
	assert_true(QuestLog.is_active(hero, &"goblin_fetishes"))
	for i in 30:
		if QuestLog.status(hero, db.quests[&"goblin_fetishes"]) == QuestLog.Status.READY:
			break
		_kill(&"goblin_shaman", 1)
		world.advance(31.0) # respawn
	assert_eq(hero.bag.count_of(fetish), 5, "stops dropping at five")
	_talk_to(&"maren", {"type": "turn_in_quest", "quest": &"goblin_fetishes", "choice": 1})
	assert_eq(hero.bag.count_of(fetish), 0, "handed over")
	assert_eq(hero.bag.count_of(db.items[&"swift_boots"]), 1, "chose the Swift Boots")
