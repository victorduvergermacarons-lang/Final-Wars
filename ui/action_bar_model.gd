class_name ActionBarModel
extends RefCounted
## What's on the ability wheel: four slots (2026-11-22, the Hades-style layout,
## replacing the WoW-style 6 pages of 10). Slot 1 (X) the weapon, 2 (Y) ranged
## attacks, 3 (A) dash or defense, 4 (B) the rest; which button fires each is fixed
## (InputActions.SLOT_INPUTS). Pure data, saved to the player's settings; the wheel
## and input read it.

signal changed

const SLOT_COUNT := InputActions.SLOT_COUNT

## Ability id per slot (&"" = empty), or "item:<item id>" for a consumable.
var slots: Array[StringName] = []
## Abilities that have been auto-placed once; never auto-placed again, so a
## slot the player cleared stays cleared.
var _auto_placed := {}
## What the player put somewhere themselves (dragged): never moved by auto_place.
var _manual := {}


func _init() -> void:
	slots.resize(SLOT_COUNT)
	slots.fill(&"")


func assign(slot: int, ability_id: StringName) -> void:
	if slot < 0 or slot >= SLOT_COUNT:
		return
	var existing := slots.find(ability_id)
	if existing >= 0 and existing != slot:
		slots[existing] = slots[slot] # dragging onto an occupied slot swaps
	slots[slot] = ability_id
	_auto_placed[ability_id] = true
	_manual[ability_id] = true
	changed.emit()


func clear(slot: int) -> void:
	if slot >= 0 and slot < SLOT_COUNT:
		slots[slot] = &""
		changed.emit()


func swap(a: int, b: int) -> void:
	var t := slots[a]
	slots[a] = slots[b]
	slots[b] = t
	for s in [slots[a], slots[b]]:
		if s != &"":
			_manual[s] = true
	changed.emit()


func slot_of(ability_id: StringName) -> int:
	return slots.find(ability_id)


## Puts abilities the hero has never had on the wheel. `slot_for(id) -> int` gives
## an ability's own slot (0 X weapon, 1 Y ranged, 2 A dash / defense, 3 B the rest;
## -1 = none): it goes there if free, or takes it from an ability that doesn't belong
## there and that the player didn't put there themselves (that one moves to a free
## slot, or off the wheel until there's room). Otherwise B, then any free slot. Ones
## that don't fit wait (the spellbook lists them). Returns true if anything changed.
func auto_place(available: Array[StringName], slot_for: Callable = Callable()) -> bool:
	var placed := false
	for id in available:
		if _auto_placed.has(id) or slots.has(id):
			_auto_placed[id] = true
			continue
		var own := _own_slot(id, slot_for)
		var at := -1
		if own >= 0 and slots[own] == &"":
			at = own
		elif own >= 0 and not _manual.has(slots[own]) and _own_slot(slots[own], slot_for) != own:
			var moved := slots[own]
			slots[own] = &""
			var to := _free_slot(moved, slot_for, own)
			if to >= 0:
				slots[to] = moved
			else:
				_auto_placed.erase(moved) # back on once there's room
			at = own
		else:
			at = _free_slot(id, slot_for)
		if at < 0:
			continue
		slots[at] = id
		_auto_placed[id] = true
		placed = true
	if placed:
		changed.emit()
	return placed


## Where an ability without a free slot of its own goes: B, X, Y, A, skipping the
## slot that is its own (already taken).
const FALLBACK := [3, 0, 1, 2]


func _free_slot(id: StringName, slot_for: Callable, taken: int = -1) -> int:
	var own := _own_slot(id, slot_for)
	for i in FALLBACK:
		if i != own and i != taken and slots[i] == &"":
			return i
	return -1


func _own_slot(id: StringName, slot_for: Callable) -> int:
	if id == &"" or not slot_for.is_valid() or is_item_slot(id):
		return -1
	var s: int = slot_for.call(id)
	return s if s >= 0 and s < SLOT_COUNT else -1


## The wheel's layout version: saves from before role placement (2026-11-22) start
## over, so every ability goes to its own slot.
const LAYOUT := 2


func to_dict() -> Dictionary:
	return {"layout": LAYOUT, "slots": slots.map(func(s): return String(s)),
			"auto_placed": _auto_placed.keys().map(func(s): return String(s)),
			"manual": _manual.keys().map(func(s): return String(s))}


func load_dict(d: Dictionary) -> void:
	_auto_placed = {}
	_manual = {}
	slots.fill(&"")
	# Older layouts (the 10-slot bar, the first wheel) start over: auto-placed again.
	if int(d.get("layout", 0)) == LAYOUT:
		var saved = d.get("slots", [])
		if typeof(saved) != TYPE_ARRAY:
			saved = []
		for i in SLOT_COUNT:
			slots[i] = StringName(saved[i]) if i < saved.size() and typeof(saved[i]) == TYPE_STRING else &""
		for id in d.get("auto_placed", []):
			_auto_placed[StringName(id)] = true
		for id in d.get("manual", []):
			_manual[StringName(id)] = true
	changed.emit()


const ITEM_PREFIX := "item:"


static func is_item_slot(entry: StringName) -> bool:
	return String(entry).begins_with(ITEM_PREFIX)


static func item_id_of(entry: StringName) -> StringName:
	return StringName(String(entry).trim_prefix(ITEM_PREFIX))


static func item_entry(item_id: StringName) -> StringName:
	return StringName(ITEM_PREFIX + String(item_id))
