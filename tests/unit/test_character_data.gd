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
	hero.ap = {&"strike": 12, &"fireball": 4}
	hero.mastered = {&"heal": db.abilities[&"heal"]}
	hero.equip_from_bag(hero.bag.index_of(db.items[&"shield"]))
	hero.bag.add(db.items[&"staff"]) # a second staff
	hero.quest_state = {"wolf_hunt": {"state": "active", "count": 3}}
	return hero


func test_round_trip_keeps_all_progress() -> void:
	var hero := _progressed_hero()
	var data := CharacterData.capture(hero)
	var json_data = JSON.parse_string(JSON.stringify(data)) # as it is on disk
	var back := CharacterData.restore(9, json_data, db)
	assert_eq(back.id, 9)
	assert_eq(back.display_name, "Ayla")
	assert_eq(back.level, 4)
	assert_eq(back.xp, 37.0)
	assert_eq(back.gold, 120)
	assert_true(back.growth.equals(hero.growth))
	assert_eq(back.ap, {&"strike": 12, &"fireball": 4})
	assert_true(back.is_mastered(&"heal"))
	assert_eq(back.equipment().size(), hero.equipment().size())
	assert_eq(back.equipped_in(EquipSlot.Id.OFF_HAND).id, &"shield")
	assert_eq(back.bag.count_of(db.items[&"staff"]), 2)
	assert_eq(back.quest_state.wolf_hunt.state, "active")
	assert_eq(int(back.quest_state.wolf_hunt.count), 3, "JSON numbers come back as floats; quests normalize them")
	assert_true(back.stats.equals(hero.stats), "same stats after reload")
	assert_eq(back.hp, back.stats.hp, "starts at full health")


func test_tampered_data_is_cleaned() -> void:
	var data := CharacterData.capture(_progressed_hero())
	data.level = -5
	data.gold = 1e12
	data.xp = "lots"
	data.name = "  \u0007Evil\nName That Is Far Too Long  "
	data.ap = {"strike": 99999, "nonexistent": 5}
	data.mastered = ["heal", "god_mode"]
	data.equipped = {"0": "sword", "99": "staff", "5": "unknown_item"}
	data.bag = [["staff", 5000], "garbage", ["dragon_egg", 1]]
	var hero := CharacterData.restore(1, data, db)
	assert_eq(hero.level, 1)
	assert_eq(hero.gold, CharacterData.MAX_GOLD)
	assert_eq(hero.xp, 0.0)
	assert_eq(hero.display_name, "EvilName That Is", "control chars stripped, 16 chars max")
	assert_eq(hero.ap, {&"strike": db.abilities[&"strike"].ap_to_master}, "clamped to the threshold")
	assert_eq(hero.mastered.keys(), [&"heal"])
	assert_null(hero.equipped_in(EquipSlot.Id.HEAD), "sword can't go on the head")
	assert_eq(hero.equipment().size(), 0)
	assert_eq(hero.bag.count_of(db.items[&"staff"]), 1, "stack clamped to 1")


func test_garbage_save_still_loads_a_fresh_hero() -> void:
	var hero := CharacterData.restore(1, {"hero": "dragon", "growth": "x"}, db)
	assert_eq(hero.level, 1)
	assert_eq(hero.def_id, &"adventurer")


func test_new_character_matches_the_starting_kit() -> void:
	var data := CharacterData.new_character("Bo", db.heroes[&"adventurer"])
	var hero := CharacterData.restore(1, data, db)
	assert_eq(hero.display_name, "Bo")
	assert_eq(hero.equipped_in(EquipSlot.Id.MAIN_HAND).id, &"sword")
	assert_eq(hero.bag.count_of(db.items[&"staff"]), 1)


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
