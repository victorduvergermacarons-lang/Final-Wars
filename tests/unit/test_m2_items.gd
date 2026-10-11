extends GutTest
## The Milestone 2 item set: archetypes, distinct abilities, rarity progression.

const ContentDBScript := preload("res://autoload/content_db.gd")

var db


func before_all() -> void:
	db = ContentDBScript.new()


func after_all() -> void:
	db.free()


func _equippables() -> Array:
	return db.items.values().filter(func(i): return i.is_equippable())


func test_twelve_items_each_teaching_its_own_ability() -> void:
	var items := _equippables()
	assert_eq(items.size(), 12)
	var abilities := {}
	for item in items:
		assert_gt(item.teaches.size(), 0, "%s teaches something" % item.id)
		for a in item.teaches:
			assert_false(abilities.has(a.id), "%s taught twice" % a.id)
			abilities[a.id] = true


func test_every_archetype_has_gear() -> void:
	var by_id := func(id): return db.items[id]
	assert_eq(by_id.call(&"iron_helm").teaches[0].id, &"taunt", "tank")
	assert_eq(by_id.call(&"greataxe").teaches[0].shape, AbilityDef.Shape.ARC, "melee damage")
	assert_true(by_id.call(&"hunting_bow").teaches[0].ranged, "ranged physical")
	assert_eq(by_id.call(&"hunting_bow").teaches[0].effects[0].damage_type, AbilityEffect.DamageType.PHYSICAL)
	assert_eq(by_id.call(&"frostweave_robe").teaches[0].effects[0].damage_type, AbilityEffect.DamageType.MAGICAL, "caster")
	assert_eq(by_id.call(&"acolytes_leggings").teaches[0].effects[0].kind, AbilityEffect.Kind.HEAL_OVER_TIME, "healer")


func test_slots_and_two_handers() -> void:
	assert_true(db.items[&"greataxe"].is_two_handed())
	assert_true(db.items[&"hunting_bow"].is_two_handed())
	var slots := {}
	for item in _equippables():
		slots[item.slot] = true
	for t in [EquipSlot.Type.HEAD, EquipSlot.Type.CHEST, EquipSlot.Type.LEGS, EquipSlot.Type.FEET,
			EquipSlot.Type.HANDS, EquipSlot.Type.MAIN_HAND, EquipSlot.Type.OFF_HAND, EquipSlot.Type.ACCESSORY]:
		assert_true(slots.has(t), "something for %s" % EquipSlot.TYPE_NAMES[t])


func test_rarer_items_are_better_and_harder_to_master() -> void:
	var by_rarity := {}
	for item in _equippables():
		if not by_rarity.has(item.rarity):
			by_rarity[item.rarity] = []
		by_rarity[item.rarity].append(item)
	assert_eq(by_rarity.keys().size(), 4, "all four tiers present")
	var avg := func(list, f):
		var total := 0.0
		for i in list:
			total += f.call(i)
		return total / list.size()
	var stat_total := func(i): return i.stats.hp / 5.0 + i.stats.mana / 5.0 + i.stats.phys_atk + i.stats.mag_atk \
			+ i.stats.phys_def + i.stats.mag_def + i.stats.speed / 2.0
	var ap := func(i): return i.teaches[0].ap_to_master
	assert_lt(avg.call(by_rarity[Rarity.Id.COMMON], stat_total), avg.call(by_rarity[Rarity.Id.EPIC], stat_total))
	assert_lt(avg.call(by_rarity[Rarity.Id.COMMON], ap), avg.call(by_rarity[Rarity.Id.UNCOMMON], ap))
	assert_lt(avg.call(by_rarity[Rarity.Id.UNCOMMON], ap), avg.call(by_rarity[Rarity.Id.RARE], ap))
	assert_lt(avg.call(by_rarity[Rarity.Id.RARE], ap), avg.call(by_rarity[Rarity.Id.EPIC], ap))


func test_rallying_roar_lasts_120_seconds() -> void:
	var roar: AbilityDef = db.abilities[&"rallying_roar"]
	assert_eq(roar.effects[0].buff.duration_seconds, 120.0)
	assert_eq(roar.shape, AbilityDef.Shape.AROUND)
	assert_eq(roar.max_range, 3)
	assert_eq(db.items[&"grizzlehide_mantle"].rarity, Rarity.Id.EPIC)


func test_greataxe_matches_the_sword_on_one_wolf_and_beats_it_on_two() -> void:
	var sword1 := BalanceSim.average(db, [[&"sword", &"holy_charm"]], [&"strike"], 1, 6)
	var axe1 := BalanceSim.average(db, [[&"greataxe", &"iron_helm", &"holy_charm"]], [&"cleave"], 1, 6)
	assert_almost_eq(axe1.seconds, sword1.seconds, sword1.seconds * 0.15, "single target within 15%%: %s vs %s" % [axe1, sword1])
	var sword2 := BalanceSim.average(db, [[&"sword", &"holy_charm"]], [&"strike"], 2, 6, 0.5)
	var axe2 := BalanceSim.average(db, [[&"greataxe", &"iron_helm", &"holy_charm"]], [&"cleave"], 2, 6, 0.5)
	assert_gt(axe2.win_rate, sword2.win_rate - 0.001, "Cleave hits both wolves: %s vs %s" % [axe2, sword2])
	assert_lt(axe2.hp_lost_pct, sword2.hp_lost_pct)


func test_bow_kills_a_wolf_at_range() -> void:
	var bow := BalanceSim.average(db, [[&"hunting_bow", &"holy_charm"]], [&"aimed_shot"], 1, 6)
	assert_eq(bow.win_rate, 1.0, str(bow))
	assert_lt(bow.seconds, 12.0, str(bow))
