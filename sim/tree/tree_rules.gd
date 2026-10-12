class_name TreeRules
extends RefCounted
## Ability-tree learning rules (CLAUDE.md, Milestone 3 §2):
## - unlocking: permanent tree Mastery ≥ the tier's requirement, every prerequisite
##   ability mastered, and any "<Tree> Mastery N" / "any element Mastery N" met;
## - the single learning slot (only it earns AP);
## - Mastery on learn, and per use against enemies near your level, up to each
##   ability's Mastery Cap (the learn bonus counts toward the cap).


## "" if `hero` may learn (and use, while its item is held) `ability`, else why not.
static func can_learn(hero: Hero, ability: AbilityDef) -> String:
	if not ability.is_tree_ability():
		return ""
	if not ability.implemented:
		return "not_implemented"
	var row := ability.sheet
	if Mastery.permanent(hero, ability.tree) + 0.0001 < float(row.get("mastery_required", 0)):
		return "mastery_too_low"
	var pre: Dictionary = row.get("prerequisites", {})
	for id in pre.get("abilities", []):
		if not hero.is_mastered(StringName(id)):
			return "prerequisite"
	for req in pre.get("mastery", []):
		var have := Mastery.best_element(hero) if req.tree == "any_element" else Mastery.permanent(hero, req.tree)
		if have + 0.0001 < float(req.amount):
			return "mastery_too_low"
	return ""


## Puts the scroll in bag slot `bag_index` into the learning slot (the previous
## scroll goes back to the bag). Returns "" or a reason.
static func learn_from_bag(hero: Hero, bag_index: int) -> String:
	var item := hero.bag.item_at(bag_index)
	if item == null:
		return "empty"
	if not item.is_scroll:
		return "not_a_scroll" if item.tree_ability() == null else "equip_weapon_first"
	var reason := _check_item(hero, item)
	if reason != "":
		return reason
	var previous := hero.learning_item
	hero.bag.remove_at(bag_index, 1)
	hero.learning_item = null
	if previous != null and previous.is_scroll:
		hero.bag.add(previous)
	hero.learning_item = item
	return ""


## Makes the weapon equipped in `slot` the learning item. Returns "" or a reason.
static func learn_from_equipped(hero: Hero, slot: int) -> String:
	var item := hero.equipped_in(slot)
	if item == null:
		return "empty"
	if item.is_scroll or item.tree_ability() == null:
		return "not_teaching"
	var reason := _check_item(hero, item)
	if reason != "":
		return reason
	if hero.learning_item != null and hero.learning_item.is_scroll:
		if hero.bag.free_slots() == 0:
			return "bag_full"
		hero.bag.add(hero.learning_item)
	hero.learning_item = item
	return ""


## Empties the learning slot (a scroll goes back to the bag). Returns "" or a reason.
static func stop_learning(hero: Hero) -> String:
	var item := hero.learning_item
	if item == null:
		return "empty"
	if item.is_scroll:
		if hero.bag.free_slots() == 0 and hero.bag.room_for(item) == 0:
			return "bag_full"
		hero.bag.add(item)
	hero.learning_item = null
	return ""


static func _check_item(hero: Hero, item: ItemDef) -> String:
	var ability := item.tree_ability()
	if ability == null:
		return "not_teaching"
	if hero.is_mastered(ability.id):
		return "already_mastered"
	return can_learn(hero, ability)


## Gives `amount` AP to the learning item's ability. Mastering it grants its
## Mastery on Learn. Returns events.
static func award_ap(hero: Hero, amount: int) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	var item := hero.learning_item
	if item == null or amount <= 0:
		return events
	var ability := item.tree_ability()
	if ability == null or hero.is_mastered(ability.id) or can_learn(hero, ability) != "":
		return events
	var total: int = mini(hero.ap.get(ability.id, 0) + amount, ability.ap_to_master)
	hero.ap[ability.id] = total
	events.append({"type": "ap", "target": hero.id, "ability": ability.id, "ap": total,
			"needed": ability.ap_to_master})
	if total >= ability.ap_to_master:
		events.append_array(master(hero, ability))
	return events


## Marks `ability` mastered and grants its Mastery on Learn. Returns events.
static func master(hero: Hero, ability: AbilityDef) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if hero.is_mastered(ability.id):
		return events
	hero.mastered[ability.id] = ability
	hero.ap[ability.id] = maxi(hero.ap.get(ability.id, 0), ability.ap_to_master)
	events.append({"type": "mastered", "target": hero.id, "ability": ability.id})
	if ability.is_tree_ability():
		var bonus := float(ability.sheet.get("mastery_on_learn", 0.0))
		events.append_array(_gain(hero, ability, bonus, true))
	return events


## Per-use Mastery: call once per use. `enemy_levels` = levels of enemies the use
## hit or targeted; `helped_in_combat` = it healed/buffed while the caster was in
## combat. Returns events.
static func on_use(hero: Hero, ability: AbilityDef, enemy_levels: Array, helped_in_combat: bool,
		rules: CombatRules) -> Array[Dictionary]:
	if not ability.is_tree_ability():
		return []
	var counts := helped_in_combat
	for lvl in enemy_levels:
		if int(lvl) >= hero.level - rules.mastery_level_window_below:
			counts = true
	if not counts:
		return []
	return _gain(hero, ability, float(ability.sheet.get("mastery_per_use", 0.0)), false)


## How much Mastery `ability` has given so far, and its cap.
static func contribution(hero: Hero, ability: AbilityDef) -> Vector2:
	return Vector2(float(hero.mastery_contrib.get(ability.id, 0.0)), float(ability.sheet.get("mastery_cap", 0.0)))


static func _gain(hero: Hero, ability: AbilityDef, amount: float, always: bool) -> Array[Dictionary]:
	var given := float(hero.mastery_contrib.get(ability.id, 0.0))
	var cap := float(ability.sheet.get("mastery_cap", 0.0))
	var add := amount if always else minf(amount, maxf(cap - given, 0.0))
	if add <= 0.0:
		return []
	hero.mastery_contrib[ability.id] = given + add
	Mastery.add_permanent(hero, ability.tree, add)
	return [{"type": "mastery", "target": hero.id, "tree": ability.tree, "ability": ability.id,
			"amount": add, "total": Mastery.permanent(hero, ability.tree)}] as Array[Dictionary]
