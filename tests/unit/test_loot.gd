extends GutTest
## Gold, loot tables, personal loot and kill rewards.

const ContentDBScript := preload("res://autoload/content_db.gd")
## The Milestone 1 starting kit (sword, staff, shield, holy charm), kept for engine tests.
const LEGACY_HERO := preload("res://tests/fixtures/legacy_adventurer.tres")

var db
var rules: CombatRules
var world: WorldSim
var a: Hero
var b: Hero
var wolf: Enemy
var table: LootTable
var gem: ItemDef
var token: ItemDef


func before_all() -> void:
	db = ContentDBScript.new()


func after_all() -> void:
	db.free()


func _item(id: StringName, stack: int) -> ItemDef:
	var i := ItemDef.new()
	i.id = id
	i.display_name = String(id)
	i.max_stack = stack
	return i


func _entry(item: ItemDef, chance: float, lo: int = 1, hi: int = 1, quest: StringName = &"") -> LootEntry:
	var e := LootEntry.new()
	e.item = item
	e.chance = chance
	e.min_count = lo
	e.max_count = hi
	e.quest_id = quest
	return e


func before_each() -> void:
	rules = db.rules
	gem = _item(&"gem", 20)
	token = _item(&"token", 20)
	table = LootTable.new()
	table.gold_min = 5
	table.gold_max = 5
	table.entries = [_entry(gem, 1.0, 2, 2), _entry(token, 1.0, 1, 1, &"wolf_hunt")]
	var def := EnemyDef.new()
	def.id = &"lootling"
	def.stats = StatBlock.make({Stat.Id.HP: 10})
	def.xp_reward = 40
	def.ap_reward = 3
	def.loot = table
	def.aggro_radius = 0
	var zone: ZoneDef = db.zones[&"greenfields"]
	world = WorldSim.new(zone, rules, 5)
	for e in world.enemies():
		e.move.place(Vector2i(29, 29)) # park the wolves out of the way
	wolf = world.add_enemy(def, Vector2i(12, 20))
	a = world.add_hero(LEGACY_HERO)
	b = world.add_hero(LEGACY_HERO)
	a.move.place(Vector2i(11, 20))
	b.move.place(Vector2i(13, 20))


func _kill_with_both_on_threat() -> Array[Dictionary]:
	wolf.threat.add(a.id, 5)
	wolf.threat.add(b.id, 5)
	wolf.state = Enemy.State.COMBAT
	a.face(Vector2i.RIGHT)
	world.submit(a.id, {"type": "cast", "ability": &"strike", "target": -1})
	return world.step()


func test_roll_respects_gold_range_and_chances() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var hero := Hero.new(1)
	table.gold_min = 2
	table.gold_max = 6
	table.entries = [_entry(gem, 0.5)]
	var drops := 0
	for i in 400:
		var r := Loot.roll(table, rng, hero)
		assert_between(r.gold, 2, 6)
		drops += r.items.size()
	assert_between(drops, 160, 240, "about half of 400")


func test_quest_items_only_drop_for_heroes_on_the_quest() -> void:
	var rng := RandomNumberGenerator.new()
	var hero := Hero.new(1)
	assert_eq(Loot.roll(table, rng, hero).items.size(), 1, "no token without the quest")
	hero.quest_state = {"wolf_hunt": {"state": "active"}}
	assert_eq(Loot.roll(table, rng, hero).items.size(), 2)


func test_every_participant_gets_their_own_loot_xp_ap_and_kill_credit() -> void:
	var events := _kill_with_both_on_threat()
	assert_false(wolf.alive)
	for h in [a, b]:
		assert_eq(h.gold, 5, "personal gold for %s" % h.id)
		assert_eq(h.bag.count_of(gem), 2, "personal items")
		assert_eq(h.xp, 20.0, "XP split")
		assert_eq(h.ap.get(&"strike", 0), 3, "AP reward to equipped abilities")
		assert_true(events.any(func(e): return e.type == "kill" and e.target == h.id and e.enemy == &"lootling"))
		assert_true(events.any(func(e): return e.type == "loot" and e.target == h.id and e.gold == 5))


func test_bystanders_get_nothing() -> void:
	wolf.threat.add(a.id, 5)
	wolf.state = Enemy.State.COMBAT
	a.face(Vector2i.RIGHT)
	world.submit(a.id, {"type": "cast", "ability": &"strike", "target": -1})
	world.step()
	assert_eq(b.gold, 0)
	assert_eq(b.bag.count_of(gem), 0)


func test_full_bag_leftovers_wait_and_can_be_taken() -> void:
	var junk := _item(&"junk", 1)
	a.bag.add(junk, a.bag.free_slots())
	var events := _kill_with_both_on_threat()
	var loot_event: Dictionary = events.filter(func(e): return e.type == "loot" and e.target == a.id)[0]
	assert_gt(loot_event.left, 0, "leftover loot id")
	var waiting := world.pending_loot_for(a.id)
	assert_eq(waiting.size(), 1)
	assert_eq(waiting[0].items, [["gem", 2]])
	assert_eq(world.pending_loot_for(b.id).size(), 0, "b had room")
	world.submit(a.id, {"type": "take_loot", "loot": loot_event.left})
	assert_true(world.step().any(func(e): return e.type == "rejected" and e.reason == "bag_full"))
	a.bag.remove_at(0)
	world.submit(a.id, {"type": "take_loot", "loot": loot_event.left})
	world.step()
	assert_eq(a.bag.count_of(gem), 2)
	assert_eq(world.pending_loot_for(a.id).size(), 0)


func test_others_cant_take_your_loot_and_it_expires() -> void:
	a.bag.add(_item(&"junk", 1), a.bag.free_slots())
	_kill_with_both_on_threat()
	var loot_id: int = world.pending_loot_for(a.id)[0].id
	world.submit(b.id, {"type": "take_loot", "loot": loot_id})
	assert_true(world.step().any(func(e): return e.type == "rejected" and e.reason == "no_loot"))
	world.advance(WorldSim.LOOT_WAIT_SECONDS + 1.0)
	assert_eq(world.pending_loot_for(a.id).size(), 0, "gone after 60 s")


func test_pending_loot_and_gold_reach_the_owner_only() -> void:
	a.bag.add(_item(&"junk", 1), a.bag.free_slots())
	_kill_with_both_on_threat()
	var snap := Snapshot.capture(world, a.id)
	for d in snap.actors:
		if d.id == a.id:
			assert_eq(d.private.gold, 5)
			assert_eq(d.private.loot.size(), 1)
		elif d.id == b.id:
			assert_false(d.has("private"))


func test_wolves_drop_gold_and_pelts() -> void:
	var wolf_def: EnemyDef = db.enemies[&"wolf"]
	assert_not_null(wolf_def.loot)
	assert_eq(wolf_def.ap_reward, 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7 # unseeded, ~1 run in 100 fell just outside the bounds
	var hero := Hero.new(1)
	var gold := 0
	var pelts := 0
	for i in 100:
		var r := Loot.roll(wolf_def.loot, rng, hero)
		gold += r.gold
		pelts += r.items.filter(func(p): return p[0].id == &"wolf_pelt").size()
	assert_between(gold, 300, 500, "2–6 gold each")
	assert_between(pelts, 45, 75, "~60% pelts")
