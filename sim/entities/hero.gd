class_name Hero
extends Actor
## A player hero: level, XP, gear, permanent item growth, AP and mastered abilities.
## Call refresh_stats() after anything that changes base, growth or gear.

## Which HeroDef this hero was made from (for saves).
var def_id: StringName = &"adventurer"
var level: int = 1
var gold: int = 0
## Per-quest progress, saved with the character (filled in by the quest system).
var quest_state := {}
## Client copy of loot waiting for this hero (filled from the host's snapshot).
var pending_loot: Array = []
var xp: float = 0.0
var base_stats: StatBlock = StatBlock.new()
## Permanent stats gained from item growth on level-ups.
var growth: StatBlock = StatBlock.new()
## Items carried but not equipped.
var bag := Bag.new()
var _equipped := {} # EquipSlot.Id -> ItemDef
## Ability id -> AP earned so far.
var ap := {}
## Ability id -> AbilityDef, usable forever (tree weapon arts need a weapon of
## that tree in hand).
var mastered := {}
## The single learning slot (ability trees): a scroll held in it, or an equipped
## weapon designated for learning. Only it earns AP toward its tree ability.
var learning_item: ItemDef = null
## Tree ability id -> Mastery it has given so far (toward its Mastery Cap).
var mastery_contrib := {}
## Where the hero died (picks the graveyard on release).
var death_tile := Vector2i.ZERO
## One buffered step, taken as soon as the current walk arrives, so holding a
## direction stays smooth despite network latency.
var pending_step: Variant = null # Vector2i or null


func _init(p_id: int = 0, p_base: StatBlock = null) -> void:
	super(p_id, Team.HEROES)
	if p_base != null:
		base_stats = p_base
	refresh_stats()
	hp = stats.hp
	mana = stats.mana


static func from_def(p_id: int, def: HeroDef) -> Hero:
	var h := Hero.new(p_id, def.base_stats.copy())
	h.def_id = def.id
	h.display_name = def.display_name
	var to_bag := def.starting_items.duplicate()
	for item in def.starting_equipment:
		h.wear(item)
		to_bag.erase(item)
	for item in to_bag:
		h.bag.add(item)
	h.give_starting_learning(def)
	h.hp = h.stats.hp
	h.mana = h.stats.mana
	return h


## Puts the def's starting scroll from the bag into the learning slot.
func give_starting_learning(def: HeroDef) -> void:
	if def.starting_learning == null:
		return
	var index := bag.index_of(def.starting_learning)
	if index >= 0:
		TreeRules.learn_from_bag(self, index)


## Which position `item` would go in: `requested` if allowed, otherwise the first
## free allowed position, otherwise the first allowed one. -1 if it can't be equipped.
func resolve_slot(item: ItemDef, requested: int = -1) -> int:
	if item == null:
		return -1
	var allowed := EquipSlot.slots_for(item.slot)
	if allowed.is_empty():
		return -1
	if requested >= 0:
		return requested if allowed.has(requested) else -1
	for s in allowed:
		if not _equipped.has(s):
			return s
	return allowed[0]


## Items that equipping `item` (into `requested`) would take off: whatever is in
## that position, plus the other hand when two-handed weapons are involved.
func displaced_by(item: ItemDef, requested: int = -1) -> Array[ItemDef]:
	var out: Array[ItemDef] = []
	var s := resolve_slot(item, requested)
	if s < 0:
		return out
	if _equipped.has(s) and _equipped[s] != item:
		out.append(_equipped[s])
	if item.is_two_handed() and _equipped.has(EquipSlot.Id.OFF_HAND):
		out.append(_equipped[EquipSlot.Id.OFF_HAND])
	if s == EquipSlot.Id.OFF_HAND and _equipped.has(EquipSlot.Id.MAIN_HAND) \
			and _equipped[EquipSlot.Id.MAIN_HAND].is_two_handed():
		out.append(_equipped[EquipSlot.Id.MAIN_HAND])
	return out


## Puts `item` on directly (no bag involved); whatever it displaces is simply
## removed. For starting gear, tests and tools. Returns false if it can't go there.
func wear(item: ItemDef, requested: int = -1) -> bool:
	var s := resolve_slot(item, requested)
	if s < 0:
		return false
	for d in displaced_by(item, s):
		_equipped.erase(_equipped.find_key(d))
	_equipped[s] = item
	refresh_stats()
	return true


## Equips the item in bag slot `index`; displaced items go into the bag.
## Returns "" or a reason: empty, cannot_equip, bag_full.
func equip_from_bag(index: int, requested: int = -1) -> String:
	var item := bag.item_at(index)
	if item == null:
		return "empty"
	var s := resolve_slot(item, requested)
	if s < 0:
		return "cannot_equip"
	var displaced := displaced_by(item, s)
	# The equipped item frees its bag slot; every displaced item needs one.
	if displaced.size() > bag.free_slots() + 1:
		return "bag_full"
	bag.remove_at(index, 1)
	wear(item, s)
	for d in displaced:
		bag.add(d)
	return ""


## Moves the item in position `slot` into the bag. Returns "" or empty/bag_full.
func unequip_to_bag(slot: int) -> String:
	var item: ItemDef = _equipped.get(slot)
	if item == null:
		return "empty"
	if bag.free_slots() == 0:
		return "bag_full"
	unequip(slot)
	bag.add(item)
	return ""


## Replaces all equipment as-is (no ownership check, no stat refresh). For
## client mirrors that receive their stats from the host.
func set_equipped_raw(by_slot: Dictionary) -> void:
	_equipped = by_slot.duplicate()


## Takes off whatever is in `slot` (the item is not kept anywhere).
func unequip(slot: EquipSlot.Id) -> void:
	_equipped.erase(slot)
	refresh_stats()


func equipped_in(slot: EquipSlot.Id) -> ItemDef:
	return _equipped.get(slot)


## Equipped items in slot order.
func equipped_items() -> Array[ItemDef]:
	var out: Array[ItemDef] = []
	for slot in EquipSlot.COUNT:
		if _equipped.has(slot):
			out.append(_equipped[slot])
	return out


## Position -> item for everything equipped.
func equipment() -> Dictionary:
	return _equipped.duplicate()


## Abilities taught by equipped items, each once, in slot order. Tree abilities
## count only when they're unlocked (TreeRules.can_learn).
func taught_abilities() -> Array[AbilityDef]:
	var out: Array[AbilityDef] = []
	var seen := {}
	var sources := equipped_items()
	if learning_item != null and learning_item.is_scroll:
		sources.append(learning_item)
	for item in sources:
		for ability in item.teaches:
			if ability == null or seen.has(ability.id):
				continue
			if ability.is_tree_ability() and TreeRules.can_learn(self, ability) != "":
				continue
			seen[ability.id] = true
			out.append(ability)
	return out


## Everything the hero can use right now: abilities of worn items (and the scroll
## in the learning slot) plus mastered ones. Mastered weapon arts need a weapon of
## their tree in hand.
func available_abilities() -> Array[AbilityDef]:
	var out := taught_abilities()
	var seen := {}
	for a in out:
		seen[a.id] = true
	var ids := mastered.keys()
	ids.sort()
	for id in ids:
		var a: AbilityDef = mastered[id]
		if seen.has(id) or (a.needs_weapon() and not wields(a.tree)):
			continue
		out.append(a)
	return out


## Whether a weapon of `tree` (Sword, Bow, Hammer) is equipped.
func wields(tree: String) -> bool:
	for item in equipped_items():
		if item.tree == tree and not item.is_scroll:
			return true
	return false


func find_ability(id: StringName) -> AbilityDef:
	for a in available_abilities():
		if a.id == id:
			return a
	return null


func die() -> void:
	death_tile = tile()
	pending_step = null
	super()


func is_mastered(id: StringName) -> bool:
	return mastered.has(id)


## Recomputes effective stats; current HP/Mana are kept but never exceed the new max.
## Also drops a learning weapon that is no longer worn.
func refresh_stats() -> void:
	if learning_item != null and not learning_item.is_scroll and not _equipped.values().has(learning_item):
		learning_item = null
	stats = StatCalc.total(base_stats, growth, equipped_items())
	hp = minf(hp, stats.hp)
	mana = minf(mana, stats.mana)


## The item earning AP: the learning slot's item, or, while the slot is empty, the
## weapon in hand (if its ability isn't mastered yet and can be learned). Null if none.
func active_learning_item() -> ItemDef:
	if learning_item != null:
		return learning_item
	for slot in [EquipSlot.Id.MAIN_HAND, EquipSlot.Id.OFF_HAND]:
		var item: ItemDef = _equipped.get(slot)
		if item == null or item.is_scroll:
			continue
		var ability := item.tree_ability()
		if ability != null and not is_mastered(ability.id) and TreeRules.can_learn(self, ability) == "":
			return item
	return null


## True when the weapon in hand is learning on its own (the learning slot is empty).
func learning_automatically() -> bool:
	return learning_item == null and active_learning_item() != null
