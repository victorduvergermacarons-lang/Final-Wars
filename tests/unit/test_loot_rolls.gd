extends GutTest
## Boss key items: Need / Greed / Pass rolls with a bad-luck bonus (LootRolls).

const LEGACY_HERO := preload("res://tests/fixtures/legacy_adventurer.tres")

var rules: CombatRules
var pp: PartyPlayDef
var world: WorldSim
var a: Hero
var b: Hero
var c: Hero
var boss: Enemy
var helm: ItemDef


func before_each() -> void:
	rules = ContentDB.rules
	pp = rules.party_play
	helm = ItemDef.new()
	helm.id = &"roll_helm"
	helm.display_name = "Roll Helm"
	helm.slot = EquipSlot.Type.HEAD
	helm.rarity = Rarity.Id.EPIC
	helm.stats = StatBlock.make({Stat.Id.PHYS_DEF: 30})
	ContentDB.items[helm.id] = helm
	var def := EnemyDef.new()
	def.id = &"roll_boss"
	def.display_name = "Roll Boss"
	def.elite = true
	def.stats = StatBlock.make({Stat.Id.HP: 10})
	def.aggro_radius = 0
	def.loot = LootTable.new()
	var entry := LootEntry.new()
	entry.item = helm
	entry.chance = 1.0
	def.loot.entries = [entry]
	world = WorldSim.new(ContentDB.zones[&"greenfields"], rules, 11)
	for e in world.enemies():
		e.move.place(Vector2i(29, 29))
	boss = world.add_enemy(def, Vector2i(12, 20))
	a = world.add_hero(LEGACY_HERO)
	b = world.add_hero(LEGACY_HERO)
	c = world.add_hero(LEGACY_HERO)
	for h in [a, b, c]:
		h.display_name = ["Ana", "Bo", "Cy"][[a, b, c].find(h)]
		h.move.place(Vector2i(10 + [a, b, c].find(h), 21))


func after_each() -> void:
	ContentDB.items.erase(&"roll_helm")


func _kill() -> Dictionary:
	for h in [a, b, c]:
		boss.threat.add(h.id, 1.0)
	boss.state = Enemy.State.COMBAT
	var events: Array[Dictionary] = []
	AbilityResolver.deal_damage(world.ctx, a, boss, &"test", 1000.0, false, events)
	world._emit_resolved(events)
	var started: Array = world.rolls.to_array()
	assert_eq(started.size(), 1, "one roll for the helm")
	if started.is_empty():
		return {}
	var s: Dictionary = started[0]
	s.roll = s.id
	return s


func _settle() -> Dictionary:
	for e in world.step():
		if e.type == "roll_result":
			return e
	return {}


func test_key_items() -> void:
	assert_true(LootRolls.is_key_item(helm, [a]), "better than an empty head")
	a.wear(helm)
	assert_false(LootRolls.is_key_item(helm, [a]), "no better than what it wears")
	assert_true(LootRolls.is_key_item(helm, [a, b]), "an upgrade for someone")
	assert_true(LootRolls.is_key_item(ContentDB.items[&"pebble_scroll"], [a]), "scrolls always")
	assert_true(LootRolls.is_key_item(ContentDB.items[&"rusty_shortsword"], [a]), "tree weapons always")
	assert_false(LootRolls.is_key_item(ContentDB.items[&"wolf_pelt"], [a]), "materials never")


func test_a_boss_key_item_is_rolled_for_the_party_not_dropped_for_each() -> void:
	var s := _kill()
	assert_eq(s.eligible.size(), 3)
	for h in [a, b, c]:
		assert_eq(world.drops.for_owner(h.id).size(), 0, "no personal copy")
	assert_almost_eq(float(s.ends_at) - world.now, pp.roll_seconds, 0.1)


func test_need_beats_greed_and_the_bonus_follows_the_rules() -> void:
	a.loot_bonus = 0
	b.loot_bonus = 300 # greed can't win against a need, whatever its total
	c.loot_bonus = 5
	var s := _kill()
	for pair in [[a, "need"], [b, "greed"], [c, "pass"]]:
		world.submit(pair[0].id, {"type": "roll", "roll": s.roll, "choice": pair[1]})
	var r := _settle()
	assert_eq(r.winner, a.id, "the only Need wins")
	assert_eq(a.bag.count_of(helm), 1, "into the winner's bag")
	assert_eq(a.loot_bonus, 0, "reset on winning")
	assert_eq(b.loot_bonus, 300, "a lost Greed changes nothing")
	assert_eq(c.loot_bonus, 5 + pp.bonus_pass, "a chosen Pass earns the bonus")
	var lines := Hud.roll_lines(r)
	assert_true(Array(lines).has("Ana: Need %d (+0) = %d" % [r.lines[0].roll, r.lines[0].total]), str(lines))
	assert_true(Array(lines).has("Cy: Pass"))
	assert_eq(lines[lines.size() - 1], "Ana wins Roll Helm.")


func test_losing_a_need_adds_ten_and_the_bonus_counts_in_the_total() -> void:
	a.loot_bonus = 1000
	b.loot_bonus = 0
	var s := _kill()
	for h in [a, b]:
		world.submit(h.id, {"type": "roll", "roll": s.roll, "choice": "need"})
	world.submit(c.id, {"type": "roll", "roll": s.roll, "choice": "greed"})
	var r := _settle()
	assert_eq(r.winner, a.id, "1000 bonus wins")
	var line_a: Dictionary = r.lines.filter(func(l): return l.hero == a.id)[0]
	assert_eq(line_a.total, line_a.roll + 1000)
	assert_eq(b.loot_bonus, pp.bonus_need_lost)
	assert_eq(c.loot_bonus, 0, "greed lost: no bonus")


func test_no_answer_is_a_pass_without_the_bonus() -> void:
	var s := _kill()
	world.submit(a.id, {"type": "roll", "roll": s.roll, "choice": "greed"})
	world.step()
	world.advance(pp.roll_seconds)
	assert_eq(a.bag.count_of(helm), 1, "the only one who rolled wins")
	assert_eq(b.loot_bonus, 0, "timed out: no pass bonus")
	assert_eq(c.loot_bonus, 0)


func test_ties_roll_again_between_the_tied() -> void:
	var s := {"eligible": [1, 2, 3], "names": {1: "A", 2: "B", 3: "C"},
			"choices": {1: "need", 2: "need", 3: "pass"}}
	var tight := PartyPlayDef.new()
	tight.roll_min = 5
	tight.roll_max = 6 # a tie half the time
	var rng := RandomNumberGenerator.new()
	var reroll_seen := false
	for seed in 40:
		rng.seed = seed
		var r := LootRolls.resolve(s, {}, rng, tight)
		assert_true(r.winner in [1, 2])
		if r.rounds > 1:
			reroll_seen = true
	assert_true(reroll_seen)


func test_an_absent_winner_gets_the_item_in_the_claim_box() -> void:
	var s := _kill()
	world.submit(b.id, {"type": "roll", "roll": s.roll, "choice": "need"})
	world.step()
	world.remove_hero(b.id) # left the game after rolling Need
	world.advance(pp.roll_seconds)
	assert_eq(world.claims.get("Bo"), [["roll_helm", 1]])
	var back := world.add_hero(LEGACY_HERO)
	back.display_name = "Bo"
	world.step()
	assert_eq(back.bag.count_of(helm), 1, "delivered when Bo is back")
	assert_false(world.claims.has("Bo"))


func test_the_bonus_is_saved_with_the_character() -> void:
	var data := CharacterData.new_character("Lucky", ContentDB.heroes[&"adventurer"])
	data.loot_bonus = 35
	var hero := CharacterData.restore(1, data, ContentDB)
	assert_eq(hero.loot_bonus, 35)
	assert_eq(CharacterData.capture(hero).loot_bonus, 35)
