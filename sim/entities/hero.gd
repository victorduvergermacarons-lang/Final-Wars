class_name Hero
extends Actor
## A player hero: level, XP, gear, permanent item growth, AP and mastered abilities.
## Call refresh_stats() after anything that changes base, growth or gear.

var level: int = 1
var xp: float = 0.0
var base_stats: StatBlock = StatBlock.new()
## Permanent stats gained from item growth on level-ups.
var growth: StatBlock = StatBlock.new()
## Items the hero owns.
var inventory: Array[ItemDef] = []
var _equipped := {} # EquipSlot.Id -> ItemDef
## Ability id -> AP earned so far.
var ap := {}
## Ability id -> AbilityDef, usable forever.
var mastered := {}
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
	h.display_name = def.display_name
	h.inventory = def.starting_items.duplicate()
	for item in def.starting_equipment:
		h.equip(item)
	h.hp = h.stats.hp
	h.mana = h.stats.mana
	return h


## Equips an owned item into its slot, replacing whatever was there.
func equip(item: ItemDef) -> bool:
	if item == null or not inventory.has(item):
		return false
	_equipped[item.slot] = item
	refresh_stats()
	return true


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


## Abilities taught by equipped items, each once, in slot order.
func taught_abilities() -> Array[AbilityDef]:
	var out: Array[AbilityDef] = []
	var seen := {}
	for item in equipped_items():
		for ability in item.teaches:
			if ability != null and not seen.has(ability.id):
				seen[ability.id] = true
				out.append(ability)
	return out


## Everything the hero can use right now: equipped-item abilities plus mastered ones.
func available_abilities() -> Array[AbilityDef]:
	var out := taught_abilities()
	var seen := {}
	for a in out:
		seen[a.id] = true
	var ids := mastered.keys()
	ids.sort()
	for id in ids:
		if not seen.has(id):
			out.append(mastered[id])
	return out


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
func refresh_stats() -> void:
	stats = StatCalc.total(base_stats, growth, equipped_items())
	hp = minf(hp, stats.hp)
	mana = minf(mana, stats.mana)
