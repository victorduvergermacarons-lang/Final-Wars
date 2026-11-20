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


func test_every_participant_gets_gold_materials_xp_ap_and_kill_credit() -> void:
	var events := _kill_with_both_on_threat()
	assert_false(wolf.alive)
	for h in [a, b]:
		assert_eq(h.gold, 5, "gold copied to %s" % h.id)
		assert_eq(h.bag.count_of(gem), 2, "materials copied, straight into the bag")
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
	assert_eq(world.drops.for_owner(b.id).size(), 0)


## Personal loot: equipment and other non-materials drop on the ground, one drop
## per hero, each rolled for that hero.
func _blade() -> ItemDef:
	var blade := _item(&"blade", 1)
	blade.slot = EquipSlot.Type.MAIN_HAND
	blade.rarity = Rarity.Id.RARE
	table.entries.append(_entry(blade, 1.0))
	return blade


func test_personal_items_drop_on_the_ground_for_each_hero() -> void:
	var blade := _blade()
	_kill_with_both_on_threat()
	for h in [a, b]:
		var mine := world.drops.for_owner(h.id)
		assert_eq(mine.size(), 1, "one drop each")
		assert_eq(mine[0].item, "blade")
		assert_eq(h.bag.count_of(blade), 0, "not in the bag until picked up")
		assert_lt(mine[0].pos.distance_to(wolf.move.pos), rules.party_play.drop_scatter + 0.01)


func test_only_the_owner_sees_and_picks_up_a_drop() -> void:
	var blade := _blade()
	_kill_with_both_on_threat()
	var a_drop: Dictionary = world.drops.for_owner(a.id)[0]
	var snap_b := Snapshot.capture(world, b.id)
	for d in snap_b.actors:
		if d.id == b.id:
			assert_false(d.private.drops.any(func(x): return x.id == a_drop.id), "b is never sent a's drop")
	world.submit(b.id, {"type": "pick_up", "drop": a_drop.id})
	assert_true(world.step().any(func(e): return e.type == "rejected" and e.reason == "no_loot"))
	a.move.place(Vector2i(2, 2))
	world.submit(a.id, {"type": "pick_up", "drop": a_drop.id})
	assert_true(world.step().any(func(e): return e.type == "rejected" and e.reason == "too_far"))
	a.move.pos = a_drop.pos
	world.submit(a.id, {"type": "pick_up", "drop": a_drop.id})
	var events := world.step()
	assert_eq(a.bag.count_of(blade), 1)
	var fed := events.any(func(e): return e.type == "looted" and e.source == a.id and e.item == "blade" \
			and e.rarity == Rarity.Id.RARE)
	assert_true(fed, "the party feed hears it")
	assert_eq(world.drops.for_owner(a.id).size(), 0)


func test_a_full_bag_leaves_the_drop_and_materials_land_at_your_feet() -> void:
	_blade()
	var junk := _item(&"junk", 1)
	a.bag.add(junk, a.bag.free_slots())
	_kill_with_both_on_threat()
	var mine := world.drops.for_owner(a.id)
	assert_eq(mine.size(), 2, "the blade, and the gems that didn't fit")
	var d: Dictionary = mine[0]
	a.move.pos = d.pos
	world.submit(a.id, {"type": "pick_up", "drop": d.id})
	assert_true(world.step().any(func(e): return e.type == "rejected" and e.reason == "bag_full"))
	assert_eq(world.drops.for_owner(a.id).size(), 2, "still on the ground")


func test_drops_expire() -> void:
	_blade()
	_kill_with_both_on_threat()
	world.advance(rules.party_play.drop_seconds + 1.0)
	assert_eq(world.drops.for_owner(a.id).size(), 0)


func test_a_boss_kill_sends_a_summary_of_everyones_loot() -> void:
	_blade()
	wolf.def.elite = true
	var events := _kill_with_both_on_threat()
	wolf.def.elite = false
	var summary: Array = events.filter(func(e): return e.type == "boss_loot")
	assert_eq(summary.size(), 1)
	assert_eq(summary[0].received.size(), 2, "both heroes listed")
	for r in summary[0].received:
		assert_eq(r.gold, 5)
		assert_true(r.items.has(["gem", 2]) and r.items.has(["blade", 1]))


func test_the_party_play_numbers_live_in_one_resource() -> void:
	var pp: PartyPlayDef = db.rules.party_play
	assert_eq(pp.resource_path, "res://content/rules/party_play.tres")
	assert_eq(pp.roll_seconds, 30.0)
	assert_eq(pp.bop_trade_seconds, 1200.0)
	assert_eq(pp.duel_radius, 10.0)


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
