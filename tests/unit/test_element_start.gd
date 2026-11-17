extends GutTest
## Starting elements: a new character picks Earth, Water, Fire or Air. Its first
## ability is mastered (scroll kept in the bag), the next scroll sits in the
## learning slot, it wears its element's shirt and pants, keeps the Rusty
## Shortsword, and the element is saved and sent to every player.

const KITS := {
	&"earth": [&"E01", &"pebble_scroll", &"granite_skin_scroll", &"E02"],
	&"water": [&"W01", &"menders_scroll", &"river_lash_scroll", &"W02"],
	&"fire": [&"F01", &"ember_fist_scroll", &"cinder_kick_scroll", &"F02"],
	&"air": [&"A01", &"open_palm_scroll", &"breeze_scroll", &"A02"],
}


func _hero(element: StringName) -> Hero:
	var data := CharacterData.new_character("Ash", ContentDB.heroes[&"adventurer"], ContentDB.elements[element])
	return CharacterData.restore(1, data, ContentDB)


func test_four_elements_load_and_validate() -> void:
	assert_eq(ContentDB.elements.keys().size(), 4)
	for id in KITS:
		assert_true(ContentDB.elements.has(id), str(id))
	assert_eq(Array(ContentDB.validate()), [])


func test_each_element_starts_with_its_kit() -> void:
	for id in KITS:
		var kit: Array = KITS[id]
		var hero := _hero(id)
		assert_eq(hero.element, id)
		assert_true(hero.is_mastered(kit[0]), "%s: %s mastered" % [id, kit[0]])
		assert_eq(hero.bag.count_of(ContentDB.items[kit[1]]), 1, "%s: its scroll stays in the bag" % id)
		assert_eq(hero.learning_item.id, kit[2], "%s: learning the next scroll" % id)
		var ids := hero.available_abilities().map(func(a): return a.id)
		assert_true(ids.has(kit[0]) and ids.has(kit[3]), "%s: both usable: %s" % [id, ids])
		assert_eq(hero.equipped_in(EquipSlot.Id.MAIN_HAND).id, &"rusty_shortsword", "keeps the sword")
		var chest := hero.equipped_in(EquipSlot.Id.CHEST)
		var legs := hero.equipped_in(EquipSlot.Id.LEGS)
		assert_true(chest != null and chest.element == id, "%s: a shirt" % id)
		assert_true(legs != null and legs.element == id, "%s: pants" % id)
		var other_scrolls := 0
		for i in hero.bag.size():
			var item := hero.bag.item_at(i)
			if item != null and item.is_scroll and item.id != kit[1]:
				other_scrolls += 1
		assert_eq(other_scrolls, 0, "%s: the default scrolls are gone" % id)


func test_clothes_lean_on_the_elements_two_stats_and_stay_small() -> void:
	var acolyte: ItemDef = ContentDB.items[&"acolytes_leggings"]
	var acolyte_total := 0.0
	for s in Stat.core():
		acolyte_total += acolyte.stats.get_stat(s)
	for e: StartingElementDef in ContentDB.elements.values():
		for item_id in e.clothes_ids:
			var item: ItemDef = ContentDB.items[item_id]
			assert_eq(item.rarity, Rarity.Id.COMMON)
			assert_true(item.teaches.is_empty() and item.tree == "", "teaches nothing")
			var total := 0.0
			for s in Stat.core():
				var v := item.stats.get_stat(s)
				if v != 0.0:
					assert_true(e.key_stats.has(int(s)), "%s gives only %s's stats" % [item_id, e.id])
				total += v
			assert_lt(total, acolyte_total * 0.5, "%s is weaker than Acolyte's Leggings" % item_id)


func test_the_element_is_saved() -> void:
	var data := CharacterData.new_character("Ash", ContentDB.heroes[&"adventurer"], ContentDB.elements[&"air"])
	assert_eq(data.element, "air")
	var back := CharacterData.capture(CharacterData.restore(1, data, ContentDB))
	assert_eq(back.element, "air")


func test_old_characters_are_unchanged() -> void:
	var data := CharacterData.new_character("Old", ContentDB.heroes[&"adventurer"])
	data.erase("element")
	var hero := CharacterData.restore(1, data, ContentDB)
	assert_eq(hero.element, &"")
	assert_eq(hero.learning_item.id, &"ember_fist_scroll", "the default kit")
	data.element = "lightning" # unknown: dropped
	assert_eq(CharacterData.restore(1, data, ContentDB).element, &"")


func test_other_players_see_the_element() -> void:
	var world := WorldSim.new(ContentDB.zones[&"town"], ContentDB.rules, 1)
	var hero := world.add_saved_hero(CharacterData.new_character("Ash", ContentDB.heroes[&"adventurer"],
			ContentDB.elements[&"water"]), ContentDB)
	var snap := Snapshot.capture(world, -1)
	var d: Dictionary = snap.actors.filter(func(a): return a.id == hero.id)[0]
	assert_eq(d.element, "water")
	assert_false(d.has("private"), "seen by another player")
	var client := ClientWorld.new(ContentDB.zones[&"town"], ContentDB.rules, ContentDB)
	client.apply_snapshot(snap)
	assert_eq(client.get_actor(hero.id).element, &"water")


func test_the_element_screen_shows_each_element_and_picks_one() -> void:
	var screen := ElementScreen.new("Ash")
	add_child_autofree(screen)
	await wait_process_frames(2)
	assert_eq(screen.buttons.size(), 4)
	var lines := ElementScreen.lines(ContentDB.elements[&"earth"])
	assert_string_contains(lines[1], "Rock Throw (mastered)")
	assert_string_contains(lines[2], "Stone Skin")
	assert_string_contains(lines[3], "Physical Attack and Physical Defense")
	watch_signals(screen)
	screen.buttons[&"fire"].pressed.emit()
	assert_signal_emitted_with_parameters(screen, "chosen", [ContentDB.elements[&"fire"]])
