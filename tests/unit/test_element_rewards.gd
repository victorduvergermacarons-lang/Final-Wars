extends GutTest
## The Act I main quests hand out a set for the hero's element (2026-11-20): Hands,
## Head and Feet given in 1-01 to 1-03, a ring or the next scroll in 1-04, a charm or
## a first weapon in 1-05, the scroll after that in 1-06.

const KEY := {
	&"earth": [Stat.Id.PHYS_ATK, Stat.Id.PHYS_DEF],
	&"water": [Stat.Id.MAG_ATK, Stat.Id.PHYS_DEF],
	&"fire": [Stat.Id.MAG_ATK, Stat.Id.MAG_DEF],
	&"air": [Stat.Id.PHYS_ATK, Stat.Id.MAG_DEF],
}
const WEAPONS := [&"rusty_shortsword", &"hunters_shortbow", &"iron_mallet"]


func _q(id: String) -> QuestDef:
	for q: QuestDef in ContentDB.quests.values():
		if String(q.id).begins_with(id):
			return q
	return null


func _ids(items: Array) -> Array:
	return items.map(func(i): return i.id)


func test_every_element_gets_its_five_common_pieces() -> void:
	var slots := [EquipSlot.Type.HANDS, EquipSlot.Type.HEAD, EquipSlot.Type.FEET,
			EquipSlot.Type.ACCESSORY, EquipSlot.Type.ACCESSORY]
	for el in KEY:
		var pieces: Array[ItemDef] = []
		pieces.append_array(_q("act1_01").items_for(el))
		pieces.append_array(_q("act1_02").items_for(el))
		pieces.append_array(_q("act1_03").items_for(el))
		pieces = pieces.filter(func(i): return i.element == el)
		pieces.append(_q("act1_04").choices_for(el)[0])
		pieces.append(_q("act1_05").choices_for(el)[0])
		assert_eq(pieces.size(), 5, "%s: five pieces" % el)
		for i in pieces.size():
			var item := pieces[i]
			assert_eq(item.slot, slots[i], "%s: %s's slot" % [el, item.display_name])
			assert_eq(item.element, el)
			assert_eq(item.rarity, Rarity.Id.COMMON, "%s is Common" % item.display_name)
			for s in KEY[el]:
				assert_gt(item.stats.get_stat(s), 0.0, "%s gives its key stats" % item.display_name)
				assert_gt(item.growth.get_stat(s), 0.0, "%s grows its key stats" % item.display_name)


func test_the_choices_by_quest() -> void:
	for el in KEY:
		assert_true(_q("act1_01").choices_for(el).is_empty(), "1-01: no choice")
		assert_eq(_ids(_q("act1_02").choices_for(el)), [&"minor_mana_potion", &"minor_health_potion"])
		assert_true(_q("act1_03").choices_for(el).is_empty(), "1-03: no choice")
		var c4 := _q("act1_04").choices_for(el)
		assert_eq(c4.size(), 2, "1-04: the ring or a scroll")
		assert_false(c4[1].teaches.is_empty(), "1-04: the second choice is a scroll")
		var c5 := _ids(_q("act1_05").choices_for(el))
		assert_eq(c5.slice(1), WEAPONS, "1-05: the charm or a first weapon")
		assert_true(_q("act1_06").choices_for(el).is_empty(), "1-06: no choice")
		assert_eq(_q("act1_06").items_for(el).size(), 1, "1-06: the next scroll")


func test_the_next_scrolls_teach_the_elements_abilities() -> void:
	var expect := {&"earth": [&"E03", &"E04"], &"water": [&"W05", &"W08"],
			&"fire": [&"F03", &"F04"], &"air": [&"A03", &"A05"]}
	for el in expect:
		var scrolls := [_q("act1_04").choices_for(el)[1], _q("act1_06").items_for(el)[0]]
		assert_eq(scrolls.map(func(s): return s.teaches[0].id), expect[el], "%s's next scrolls" % el)


func test_no_weapon_before_quest_5() -> void:
	for id in ["act1_01", "act1_02", "act1_03", "act1_04"]:
		for el in [&"earth", &"water", &"fire", &"air", &""]:
			var q := _q(id)
			for item in q.items_for(el) + q.choices_for(el):
				assert_false(item.slot in [EquipSlot.Type.MAIN_HAND, EquipSlot.Type.TWO_HAND],
						"%s offers no weapon (%s)" % [id, item.display_name])


func test_turning_in_gives_the_heros_own_piece() -> void:
	var world := WorldSim.new(ContentDB.zones[&"town"], ContentDB.rules, 1)
	var hero := world.add_hero(ContentDB.heroes[&"adventurer"])
	CharacterData.apply_element(hero, ContentDB.elements[&"water"], ContentDB)
	var q := _q("act1_01")
	var done: Array = q.objectives.map(func(o): return o.needed())
	hero.quest_state[String(q.id)] = {"state": "active", "progress": done}
	var r := QuestLog.turn_in(hero, q, -1, ContentDB.rules)
	assert_eq(r.reason, "")
	assert_eq(hero.bag.count_of(ContentDB.items[&"riverweave_gloves"]), 1, "the Water gloves")
	assert_eq(hero.bag.count_of(ContentDB.items[&"quarrymans_gloves"]), 0, "not the Earth ones")


func test_a_hero_without_an_element_chooses_any_elements_piece() -> void:
	var c1 := _q("act1_01").choices_for(&"")
	assert_eq(c1.size(), 4, "one gloves per element")
	assert_true(_q("act1_01").items_for(&"").all(func(i): return i.element == &""), "nothing element-bound given")
	assert_eq(_q("act1_05").choices_for(&"").size(), 4 + 3, "four charms and the weapons")
