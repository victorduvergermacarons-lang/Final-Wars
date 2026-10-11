class_name ActionBarModel
extends RefCounted
## What's on the action bar and which key fires each slot. Pure data, saved to
## the player's settings; the view and input read it.

signal changed

const SLOT_COUNT := 10
const DEFAULT_KEYS: Array[int] = [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9, KEY_0]

## Ability id per slot (&"" = empty).
var slots: Array[StringName] = []
## Physical keycode per slot (KEY_NONE = unbound).
var keys: Array[int] = []
## Abilities that have been auto-placed once; never auto-placed again, so a
## slot the player cleared stays cleared.
var _auto_placed := {}


func _init() -> void:
	slots.resize(SLOT_COUNT)
	slots.fill(&"")
	keys = DEFAULT_KEYS.duplicate()


func assign(slot: int, ability_id: StringName) -> void:
	if slot < 0 or slot >= SLOT_COUNT:
		return
	var existing := slots.find(ability_id)
	if existing >= 0 and existing != slot:
		slots[existing] = slots[slot] # dragging onto an occupied slot swaps
	slots[slot] = ability_id
	_auto_placed[ability_id] = true
	changed.emit()


func clear(slot: int) -> void:
	if slot >= 0 and slot < SLOT_COUNT:
		slots[slot] = &""
		changed.emit()


func swap(a: int, b: int) -> void:
	var t := slots[a]
	slots[a] = slots[b]
	slots[b] = t
	changed.emit()


func slot_of(ability_id: StringName) -> int:
	return slots.find(ability_id)


## Puts abilities the hero has never had on the bar into the first empty slots.
## Returns true if anything changed.
func auto_place(available: Array[StringName]) -> bool:
	var placed := false
	for id in available:
		if _auto_placed.has(id) or slots.has(id):
			_auto_placed[id] = true
			continue
		var empty := slots.find(&"")
		if empty < 0:
			break
		slots[empty] = id
		_auto_placed[id] = true
		placed = true
	if placed:
		changed.emit()
	return placed


## Binds `key` to `slot`; a slot that had that key loses it. Returns false if the
## key is reserved for something else (movement, targeting, panels…).
func set_key(slot: int, key: int) -> bool:
	if InputActions.is_reserved_key(key):
		return false
	for i in SLOT_COUNT:
		if keys[i] == key:
			keys[i] = KEY_NONE
	keys[slot] = key
	changed.emit()
	return true


func key_label(slot: int) -> String:
	return "" if keys[slot] == KEY_NONE else OS.get_keycode_string(keys[slot])


func to_dict() -> Dictionary:
	return {"slots": slots.map(func(s): return String(s)), "keys": keys.duplicate(),
			"auto_placed": _auto_placed.keys().map(func(s): return String(s))}


func load_dict(d: Dictionary) -> void:
	var s: Array = d.get("slots", [])
	var k: Array = d.get("keys", [])
	for i in SLOT_COUNT:
		slots[i] = StringName(s[i]) if i < s.size() and typeof(s[i]) == TYPE_STRING else &""
		keys[i] = int(k[i]) if i < k.size() and typeof(k[i]) == TYPE_INT else DEFAULT_KEYS[i]
	_auto_placed = {}
	for id in d.get("auto_placed", []):
		_auto_placed[StringName(id)] = true
	changed.emit()
