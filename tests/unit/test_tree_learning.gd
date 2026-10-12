extends GutTest
## Ability-tree learning: unlock checks, the learning slot, AP, Mastery on learn
## and per use (with caps and the level window), saving.

var abilities := {}
var items := {}
var hero: Hero
var rules: CombatRules


func before_each() -> void:
	# A private copy of the tree content with every ability treated as implemented.
	var built := TreeContent.build(ContentDB.tree, TreeTuning.new(), "res://no_behaviors")
	abilities = built.abilities
	items = built.items
	for a in abilities.values():
		a.implemented = true
	rules = CombatRules.new()
	hero = Hero.new(1, StatBlock.make({Stat.Id.HP: 100, Stat.Id.MANA: 50}))


func _scroll(ability_id: StringName) -> ItemDef:
	return items[StringName(abilities[ability_id].sheet.item_id)]


func _give(item: ItemDef) -> int:
	hero.bag.add(item)
	return hero.bag.index_of(item)


func test_items_exist_for_every_ability() -> void:
	assert_eq(items.size(), 145)
	var ember: ItemDef = items[&"ember_fist_scroll"]
	assert_true(ember.is_scroll)
	assert_eq(ember.slot, EquipSlot.Type.NONE, "scrolls aren't worn")
	assert_eq(ember.tree_ability().id, &"F01")
	var rusty: ItemDef = items[&"rusty_shortsword"]
	assert_eq(rusty.slot, EquipSlot.Type.MAIN_HAND, "swords are one-handed")
	assert_eq(items[&"yew_longbow"].slot, EquipSlot.Type.TWO_HAND)
	assert_eq(items[&"iron_mallet"].slot, EquipSlot.Type.TWO_HAND)
	assert_gt(rusty.stats.phys_atk, 0.0)
	assert_eq(items[&"scroll_of_burning_feet"].rarity, Rarity.Id.UNCOMMON, "tier 2 = Uncommon")
	assert_eq(abilities[&"F05"].ap_to_master, 30, "tier 2 AP")


func test_unlock_needs_tier_mastery_and_prerequisites() -> void:
	var dash: AbilityDef = abilities[&"F05"] # T2, needs Fire Kick
	assert_eq(TreeRules.can_learn(hero, abilities[&"F01"]), "", "tier 1 is open")
	assert_eq(TreeRules.can_learn(hero, dash), "mastery_too_low")
	Mastery.add_permanent(hero, "Fire", 150)
	assert_eq(TreeRules.can_learn(hero, dash), "prerequisite")
	hero.mastered[&"F02"] = abilities[&"F02"]
	assert_eq(TreeRules.can_learn(hero, dash), "")


func test_gear_mastery_does_not_unlock() -> void:
	var charm := ItemDef.new()
	charm.slot = EquipSlot.Type.ACCESSORY
	charm.stats = StatBlock.make({Stat.Id.FIRE_MASTERY: 500})
	hero.wear(charm)
	hero.mastered[&"F02"] = abilities[&"F02"]
	assert_eq(TreeRules.can_learn(hero, abilities[&"F05"]), "mastery_too_low")


func test_cross_tree_and_any_element_requirements() -> void:
	var bolt: AbilityDef = abilities[&"F17"] # Fire Stream; Air Mastery 350
	Mastery.add_permanent(hero, "Fire", 600)
	hero.mastered[&"F12"] = abilities[&"F12"]
	assert_eq(TreeRules.can_learn(hero, bolt), "mastery_too_low", "needs Air 350 too")
	Mastery.add_permanent(hero, "Air", 350)
	assert_eq(TreeRules.can_learn(hero, bolt), "")
	var edge: AbilityDef = abilities[&"S18"] # Flurry; any element Mastery 350
	Mastery.add_permanent(hero, "Sword", 600)
	hero.mastered[&"S10"] = abilities[&"S10"]
	assert_eq(TreeRules.can_learn(hero, edge), "", "Air 350 counts as any element")


func test_scroll_goes_into_the_learning_slot_and_back() -> void:
	var ember := _scroll(&"F01")
	var mender := _scroll(&"W01")
	assert_eq(TreeRules.learn_from_bag(hero, _give(ember)), "")
	assert_eq(hero.learning_item, ember)
	assert_eq(hero.bag.count_of(ember), 0, "held in the slot, not the bag")
	assert_eq(TreeRules.learn_from_bag(hero, _give(mender)), "")
	assert_eq(hero.learning_item, mender)
	assert_eq(hero.bag.count_of(ember), 1, "the previous scroll went back to the bag")
	assert_eq(TreeRules.stop_learning(hero), "")
	assert_null(hero.learning_item)
	assert_eq(hero.bag.count_of(mender), 1)


func test_locked_and_unimplemented_items_are_refused() -> void:
	assert_eq(TreeRules.learn_from_bag(hero, _give(_scroll(&"F05"))), "mastery_too_low")
	abilities[&"F01"].implemented = false
	assert_eq(TreeRules.learn_from_bag(hero, _give(_scroll(&"F01"))), "not_implemented")


func test_weapon_learning_needs_it_worn() -> void:
	var sword: ItemDef = items[&"rusty_shortsword"]
	assert_eq(TreeRules.learn_from_bag(hero, _give(sword)), "equip_weapon_first")
	hero.wear(sword)
	assert_eq(TreeRules.learn_from_equipped(hero, EquipSlot.Id.MAIN_HAND), "")
	assert_eq(hero.learning_item, sword)
	hero.unequip(EquipSlot.Id.MAIN_HAND)
	assert_null(hero.learning_item, "taking the weapon off empties the slot")


func test_only_the_learning_item_earns_ap_and_mastering_grants_mastery() -> void:
	var sword: ItemDef = items[&"rusty_shortsword"]
	hero.wear(sword)
	TreeRules.learn_from_bag(hero, _give(_scroll(&"F01")))
	ApMastery.award(hero, 10)
	assert_eq(hero.ap.get(&"F01", 0), 10)
	assert_eq(hero.ap.get(&"S01", 0), 0, "the worn sword isn't the learning item")
	var events := ApMastery.award(hero, 10)
	assert_true(hero.is_mastered(&"F01"))
	assert_true(events.any(func(e): return e.type == "mastered"))
	assert_eq(Mastery.permanent(hero, "Fire"), 5.0, "Mastery on Learn")
	assert_eq(TreeRules.contribution(hero, abilities[&"F01"]), Vector2(5, 50))


func test_what_can_be_used() -> void:
	var sword: ItemDef = items[&"rusty_shortsword"]
	hero.wear(sword)
	var ids := func(): return hero.available_abilities().map(func(a): return a.id)
	assert_has(ids.call(), &"S01", "a worn weapon's unlocked art is usable while learning it")
	TreeRules.learn_from_bag(hero, _give(_scroll(&"F01")))
	assert_has(ids.call(), &"F01", "the scroll in the learning slot is usable")
	TreeRules.stop_learning(hero)
	assert_does_not_have(ids.call(), &"F01")
	TreeRules.master(hero, abilities[&"F01"])
	TreeRules.master(hero, abilities[&"S01"])
	hero.unequip(EquipSlot.Id.MAIN_HAND)
	assert_has(ids.call(), &"F01", "mastered bending works without its scroll")
	assert_does_not_have(ids.call(), &"S01", "mastered sword arts need a sword in hand")
	hero.wear(items[&"twinfang_blade"])
	assert_has(ids.call(), &"S01", "any sword will do")


func test_per_use_mastery_window_and_cap() -> void:
	var punch: AbilityDef = abilities[&"F01"] # +0.2 per use, cap 50
	hero.level = 10
	assert_eq(TreeRules.on_use(hero, punch, [6], false, rules).size(), 0, "4 levels below: no Mastery")
	assert_eq(TreeRules.on_use(hero, punch, [7], false, rules).size(), 1, "3 below counts")
	assert_eq(TreeRules.on_use(hero, punch, [30], false, rules).size(), 1, "any level above counts")
	assert_eq(TreeRules.on_use(hero, abilities[&"W01"], [], false, rules).size(), 0, "a heal out of combat doesn't count")
	assert_eq(TreeRules.on_use(hero, abilities[&"W01"], [], true, rules).size(), 1, "a heal in combat counts")
	for i in 300:
		TreeRules.on_use(hero, punch, [10], false, rules)
	assert_almost_eq(TreeRules.contribution(hero, punch).x, 50.0, 0.001, "stops at the cap")
	TreeRules.master(hero, punch)
	assert_almost_eq(Mastery.permanent(hero, "Fire"), 55.0, 0.001, "the learn bonus is still granted")


func test_learning_slot_and_contributions_save() -> void:
	var content := {"heroes": ContentDB.heroes, "items": items, "abilities": abilities, "quests": {}}
	TreeRules.learn_from_bag(hero, _give(_scroll(&"W01")))
	TreeRules.on_use(hero, abilities[&"W01"], [], true, rules)
	var data = JSON.parse_string(JSON.stringify(CharacterData.capture(hero)))
	var back := CharacterData.restore(5, data, content)
	assert_eq(back.learning_item, _scroll(&"W01"))
	assert_almost_eq(float(back.mastery_contrib[&"W01"]), 0.2, 0.0001)


func test_learn_intents() -> void:
	assert_eq(Intents.sanitize({"type": "learn", "bag_index": 3}), {"type": "learn", "bag_index": 3})
	assert_eq(Intents.sanitize({"type": "learn", "slot": 5}), {"type": "learn", "slot": 5})
	assert_eq(Intents.sanitize({"type": "learn"}), {}, "needs a bag index or a slot")
	assert_eq(Intents.sanitize({"type": "stop_learning"}), {"type": "stop_learning"})
