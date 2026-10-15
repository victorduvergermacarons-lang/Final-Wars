extends GutTest
## Character saves: round trip, validation of tampered data, and the store on disk.

const ContentDBScript := preload("res://autoload/content_db.gd")
const DIR := "user://test_characters"

var db


func before_all() -> void:
	db = ContentDBScript.new()


func after_all() -> void:
	db.free()
	var abs_dir := ProjectSettings.globalize_path(DIR)
	for f in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(abs_dir.path_join(f))
	DirAccess.remove_absolute(abs_dir)


func _progressed_hero() -> Hero:
	var hero := Hero.from_def(5, db.heroes[&"adventurer"])
	hero.display_name = "Ayla"
	hero.level = 4
	hero.xp = 37
	hero.gold = 120
	hero.growth = StatBlock.make({Stat.Id.PHYS_ATK: 6, Stat.Id.HP: 15})
	hero.ap = {&"S01": 12, &"F01": 4}
	hero.mastered = {&"W01": db.abilities[&"W01"]}
	hero.bag.add(db.items[&"iron_helm"])
	hero.equip_from_bag(hero.bag.index_of(db.items[&"iron_helm"]))
	hero.bag.add(db.items[&"menders_scroll"]) # a second one
	hero.quest_state = {"wolf_hunt": {"state": "active", "progress": [3], "ready": false}}
	return hero


func test_round_trip_keeps_all_progress() -> void:
	var hero := _progressed_hero()
	var data := CharacterData.capture(hero)
	var json_data = JSON.parse_string(JSON.stringify(data)) # as it is on disk
	var q := QuestDef.new()
	q.id = &"wolf_hunt"
	var o := QuestObjective.new()
	o.enemy = &"wolf"
	o.count = 5
	q.objectives = [o] as Array[QuestObjective]
	db.quests[q.id] = q
	var back := CharacterData.restore(9, json_data, db)
	db.quests.erase(q.id)
	assert_eq(back.id, 9)
	assert_eq(back.display_name, "Ayla")
	assert_eq(back.level, 4)
	assert_eq(back.xp, 37.0)
	assert_eq(back.gold, 120)
	assert_true(back.growth.equals(hero.growth))
	assert_eq(back.ap, {&"S01": 12, &"F01": 4})
	assert_true(back.is_mastered(&"W01"))
	assert_eq(back.equipment().size(), hero.equipment().size())
	assert_eq(back.equipped_in(EquipSlot.Id.HEAD).id, &"iron_helm")
	assert_eq(back.learning_item.id, &"ember_fist_scroll")
	assert_eq(back.bag.count_of(db.items[&"menders_scroll"]), 2)
	assert_eq(back.quest_state.wolf_hunt.state, "active")
	assert_eq(back.quest_state.wolf_hunt.progress, [3], "JSON numbers come back as floats; quests normalize them")
	assert_eq(typeof(back.quest_state.wolf_hunt.progress[0]), TYPE_INT)
	assert_true(back.stats.equals(hero.stats), "same stats after reload")
	assert_eq(back.hp, back.stats.hp, "starts at full health")


func test_tampered_data_is_cleaned() -> void:
	var data := CharacterData.capture(_progressed_hero())
	data.level = -5
	data.gold = 1e12
	data.xp = "lots"
	data.name = "  \u0007Evil\nName That Is Far Too Long  "
	data.ap = {"S01": 99999, "nonexistent": 5}
	data.mastered = ["W01", "god_mode"]
	data.equipped = {"0": "rusty_shortsword", "99": "iron_mallet", "5": "unknown_item"}
	data.bag = [["iron_helm", 5000], "garbage", ["dragon_egg", 1]]
	var hero := CharacterData.restore(1, data, db)
	assert_eq(hero.level, 1)
	assert_eq(hero.gold, CharacterData.MAX_GOLD)
	assert_eq(hero.xp, 0.0)
	assert_eq(hero.display_name, "EvilName That Is", "control chars stripped, 16 chars max")
	assert_eq(hero.ap, {&"S01": db.abilities[&"S01"].ap_to_master}, "clamped to the threshold")
	assert_eq(hero.mastered.keys(), [&"W01"])
	assert_null(hero.equipped_in(EquipSlot.Id.HEAD), "sword can't go on the head")
	assert_eq(hero.equipment().size(), 0)
	assert_eq(hero.bag.count_of(db.items[&"iron_helm"]), 1, "stack clamped to 1")


## Milestone 3 retired the old abilities and their gear: an older character loses
## them and gets the new starting kit, keeping everything else.
func test_pre_milestone_3_character_is_converted() -> void:
	var data := {"name": "Old", "level": 5, "gold": 77, "growth": {"phys_atk": 6.0},
			"equipped": {str(EquipSlot.Id.MAIN_HAND): "sword", str(EquipSlot.Id.OFF_HAND): "shield",
				str(EquipSlot.Id.HEAD): "iron_helm"},
			"bag": [["staff", 1], ["minor_health_potion", 3]],
			"ap": {"fireball": 10}, "mastered": ["strike", "heal"]}
	var hero := CharacterData.restore(1, data, db)
	assert_eq(hero.level, 5)
	assert_eq(hero.gold, 77)
	assert_eq(hero.equipped_in(EquipSlot.Id.HEAD).id, &"iron_helm", "armor stays")
	assert_eq(hero.equipped_in(EquipSlot.Id.MAIN_HAND).id, &"rusty_shortsword")
	assert_null(hero.equipped_in(EquipSlot.Id.OFF_HAND))
	assert_eq(hero.bag.count_of(db.items[&"staff"]), 0)
	assert_eq(hero.bag.count_of(db.items[&"minor_health_potion"]), 3)
	assert_eq(hero.learning_item.id, &"ember_fist_scroll")
	assert_eq(hero.bag.count_of(db.items[&"menders_scroll"]), 1)
	assert_true(hero.mastered.is_empty(), "old abilities retired")
	assert_true(hero.ap.is_empty())


func test_renamed_items_survive_loading() -> void:
	var data := CharacterData.new_character("Kit", db.heroes[&"adventurer"])
	data.bag = [["kindling_scroll", 1]]
	var hero := CharacterData.restore(1, data, db)
	assert_eq(hero.bag.count_of(db.items[&"sun_warriors_breath_scroll"]), 1)


func test_garbage_save_still_loads_a_fresh_hero() -> void:
	var hero := CharacterData.restore(1, {"hero": "dragon", "growth": "x"}, db)
	assert_eq(hero.level, 1)
	assert_eq(hero.def_id, &"adventurer")


func test_new_character_matches_the_starting_kit() -> void:
	var data := CharacterData.new_character("Bo", db.heroes[&"adventurer"])
	var hero := CharacterData.restore(1, data, db)
	assert_eq(hero.display_name, "Bo")
	assert_eq(hero.equipped_in(EquipSlot.Id.MAIN_HAND).id, &"rusty_shortsword")
	assert_eq(hero.learning_item.id, &"ember_fist_scroll")
	assert_eq(hero.bag.count_of(db.items[&"menders_scroll"]), 1)


func test_store_saves_lists_and_loads() -> void:
	var store := CharacterStore.new(DIR)
	store.save(CharacterData.capture(_progressed_hero()))
	store.save(CharacterData.new_character("Bob the Brave", db.heroes[&"adventurer"]))
	assert_eq(store.list(), PackedStringArray(["Ayla", "Bob the Brave"]))
	assert_true(store.exists("Bob the Brave"))
	assert_eq(int(store.load_character("Ayla").level), 4, "JSON numbers load as floats")
	assert_eq(CharacterStore.slug("Bob the Brave!"), "bob_the_brave")
	store.delete("Bob the Brave")
	assert_false(store.exists("Bob the Brave"))
	assert_eq(store.load_character("Nobody"), {})


func test_corrupt_save_file_loads_as_missing() -> void:
	var store := CharacterStore.new(DIR)
	var f := FileAccess.open(DIR.path_join("broken.json"), FileAccess.WRITE)
	f.store_string("{oops")
	f.close()
	assert_eq(store.load_character("broken"), {})
	assert_false(store.list().has("broken"))
