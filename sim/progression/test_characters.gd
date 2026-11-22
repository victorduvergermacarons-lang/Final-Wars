class_name TestCharacters
extends RefCounted
## Four ready-made characters for trying the element kits (2026-11-22, user
## request): one per element, level 10, every ability of their element's kit and
## of the three weapons mastered, a sword in hand and the bow and hammer in the bag.
## The main menu adds any that are missing (debug builds).

const ELEMENTS := [&"fire", &"water", &"earth", &"air"]
const LEVEL := 10


static func name_for(element: StringName) -> String:
	return "%s Tester" % String(element).capitalize()


## The saved data of the test character for `element`.
static func make(element: StringName, content) -> Dictionary:
	var hero := Hero.from_def(0, content.heroes[&"adventurer"])
	hero.display_name = name_for(element)
	CharacterData.apply_element(hero, content.elements[element], content)
	hero.wear(content.items[&"rusty_shortsword"])
	for id in [&"hunters_shortbow", &"iron_mallet"]:
		hero.bag.add(content.items[id])
	for i in LEVEL - 1:
		Leveling.level_up(hero, content.rules)
	for id in ElementKits.all_ability_ids(element):
		if content.abilities.has(id):
			hero.mastered[id] = content.abilities[id]
	var stats := hero.current_stats(0.0)
	hero.hp = stats.hp
	hero.mana = stats.mana
	return CharacterData.capture(hero)


## Saves whichever test characters `store` doesn't have yet. Returns their names.
static func ensure(store: CharacterStore, content) -> Array[String]:
	var made: Array[String] = []
	for e in ELEMENTS:
		if not store.exists(name_for(e)):
			store.save(make(e, content))
			made.append(name_for(e))
	return made
