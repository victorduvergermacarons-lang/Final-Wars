extends GutTest
## The action bar since 2026-11-28: every learned ability on it (no stance entries),
## a bending ability of another stance enters that stance first, each character keeps
## its own bar, and deleting a character forgets its bar.

const PATH := "user://test_hotbar_settings.cfg"
const DIR := "user://test_hotbar_chars"


func before_each() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


func after_all() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


func test_each_character_keeps_its_own_bar() -> void:
	var a := ActionBarModel.new()
	a.assign(0, &"W02")
	a.set_key(1, KEY_Q)
	SettingsStore.save_action_bar(a, PATH, "Kanna")
	var shared := ActionBarModel.new()
	shared.assign(0, &"F01")
	shared.set_key(2, KEY_G)
	SettingsStore.save_action_bar(shared, PATH) # the old shared layout
	var back := ActionBarModel.new()
	SettingsStore.load_action_bar(back, PATH, "Kanna")
	assert_eq(back.slots[0], &"W02")
	assert_eq(back.keys[1], KEY_Q)
	var fresh := ActionBarModel.new()
	SettingsStore.load_action_bar(fresh, PATH, "Zuko")
	assert_eq(fresh.slots, ActionBarModel.new().slots, "a new character starts with an empty bar")
	assert_eq(fresh.keys[2], KEY_G, "…and the keybinds of the shared layout")
	assert_false(fresh.has_anywhere(&"F01"), "not another character's abilities")


func test_old_stance_entries_are_dropped_and_their_abilities_come_back() -> void:
	var bar := ActionBarModel.new()
	bar.load_dict({"pages": [["stance:Water:1", "stance:Water:2", "S01"]], "auto_placed": ["stances", "S01"]})
	assert_false(bar.slots.any(func(e): return ActionBarModel.is_stance_slot(e)))
	assert_eq(bar.slots[2], &"S01")
	var ids: Array[StringName] = [&"W01", &"W02", &"S01"]
	bar.auto_place(ids)
	assert_true(bar.has_anywhere(&"W01") and bar.has_anywhere(&"W02"), "bending abilities placed again")


func test_another_stance_is_entered_first() -> void:
	var hero := Hero.new()
	var whip: AbilityDef = ContentDB.abilities[&"W02"]
	var tide: AbilityDef = ContentDB.abilities[&"W07"]
	assert_true(PlayerInput.needs_stance(hero, whip), "out of any stance")
	hero.stance_tree = "Water"
	hero.stance = 1
	assert_false(PlayerInput.needs_stance(hero, whip), "in its stance: cast")
	assert_true(PlayerInput.needs_stance(hero, tide), "Leeching Tide is stance 2: switch")
	assert_false(PlayerInput.needs_stance(hero, ContentDB.abilities[&"S01"]), "weapon arts have no stance")


func test_deleting_a_character_forgets_its_bar() -> void:
	var store := CharacterStore.new(DIR)
	store.save(CharacterData.new_character("Kanna", ContentDB.heroes[&"adventurer"]))
	var bar := ActionBarModel.new()
	bar.assign(0, &"W02")
	SettingsStore.save_action_bar(bar, PATH, "Kanna")
	store.delete("Kanna")
	SettingsStore.forget_action_bar("Kanna", PATH)
	assert_false(store.exists("Kanna"))
	var back := ActionBarModel.new()
	SettingsStore.load_action_bar(back, PATH, "Kanna")
	assert_false(back.has_anywhere(&"W02"))
