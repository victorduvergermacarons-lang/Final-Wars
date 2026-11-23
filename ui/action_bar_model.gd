class_name ActionBarModel
extends RefCounted
## What's on the action bars and which key fires each slot. Pure data, saved to
## the player's settings; the view and input read it.
## WoW-style pages: PAGE_COUNT bars of SLOT_COUNT slots; one is shown at a time
## (Shift+1..6 switches) and the slot keys fire the shown bar's slots.

signal changed

const SLOT_COUNT := 10
const PAGE_COUNT := 6
const DEFAULT_KEYS: Array[int] = [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9, KEY_0]

## Every page's slots (each an Array[StringName] of SLOT_COUNT).
var pages: Array = []
## Index of the page shown (0-based).
var page: int = 0
## The shown page's slots: ability id per slot (&"" = empty), or "item:<item id>"
## for a consumable. Same array as pages[page].
var slots: Array[StringName] = []
## Physical keycode per slot (KEY_NONE = unbound).
var keys: Array[int] = []
## Abilities that have been auto-placed once; never auto-placed again, so a
## slot the player cleared stays cleared.
var _auto_placed := {}


func _init() -> void:
	for p in PAGE_COUNT:
		var s: Array[StringName] = []
		s.resize(SLOT_COUNT)
		s.fill(&"")
		pages.append(s)
	slots = pages[0]
	keys = DEFAULT_KEYS.duplicate()


## Shows page `p` (0-based; wraps around).
func set_page(p: int) -> void:
	page = posmod(p, PAGE_COUNT)
	slots = pages[page]
	changed.emit()


## Whether `id` is on any page.
func has_anywhere(id: StringName) -> bool:
	return pages.any(func(s): return s.has(id))


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


## Puts abilities the hero has never had on a bar into the first empty slot,
## page 1 first. Returns true if anything changed.
func auto_place(available: Array[StringName]) -> bool:
	var placed := false
	for id in available:
		if _auto_placed.has(id) or has_anywhere(id):
			_auto_placed[id] = true
			continue
		var target: Array = []
		for s in pages:
			if s.has(&""):
				target = s
				break
		if target.is_empty():
			break
		target[target.find(&"")] = id
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
	return {"pages": pages.map(func(p): return p.map(func(s): return String(s))), "page": page,
			"keys": keys.duplicate(), "auto_placed": _auto_placed.keys().map(func(s): return String(s))}


func load_dict(d: Dictionary) -> void:
	# Older saves had a single bar under "slots".
	var saved: Array = d.get("pages", [d.get("slots", [])])
	for p in PAGE_COUNT:
		var s: Array = saved[p] if p < saved.size() and typeof(saved[p]) == TYPE_ARRAY else []
		for i in SLOT_COUNT:
			pages[p][i] = StringName(s[i]) if i < s.size() and typeof(s[i]) == TYPE_STRING else &""
	var k: Array = d.get("keys", [])
	for i in SLOT_COUNT:
		keys[i] = int(k[i]) if i < k.size() and typeof(k[i]) == TYPE_INT else DEFAULT_KEYS[i]
	var pg = d.get("page", 0)
	page = clampi(int(pg) if typeof(pg) in [TYPE_INT, TYPE_FLOAT] else 0, 0, PAGE_COUNT - 1)
	slots = pages[page]
	_auto_placed = {}
	for id in d.get("auto_placed", []):
		_auto_placed[StringName(id)] = true
	changed.emit()


const ITEM_PREFIX := "item:"


static func is_item_slot(entry: StringName) -> bool:
	return String(entry).begins_with(ITEM_PREFIX)


static func item_id_of(entry: StringName) -> StringName:
	return StringName(String(entry).trim_prefix(ITEM_PREFIX))


static func item_entry(item_id: StringName) -> StringName:
	return StringName(ITEM_PREFIX + String(item_id))


# --- Stances (stance rework, 2026-11-23) ---------------------------------------
## A slot can hold a bending stance: "stance:<Tree>:<n>". Pressed out of a stance it
## enters it; in a stance, keys 1-4 cast its branches instead (PlayerInput.use_slot)
## and 5-0 keep their slots, so a stance there switches straight to it.
const STANCE_PREFIX := "stance:"


static func stance_entry(tree: String, n: int) -> StringName:
	return StringName("%s%s:%d" % [STANCE_PREFIX, tree, n])


static func is_stance_slot(entry: StringName) -> bool:
	return String(entry).begins_with(STANCE_PREFIX)


## [tree, n] of a stance slot.
static func stance_of(entry: StringName) -> Array:
	var parts := String(entry).trim_prefix(STANCE_PREFIX).split(":")
	return [parts[0], int(parts[1])] if parts.size() == 2 else ["", 0]


## Puts the stances of the bending trees the hero knows on the bar, once per tree:
## the hero's own element (`primary`) on page 1's slots 1-5 (whatever was there moves
## to the first empty slots), the others into the first empty slots. The first time,
## bending abilities on the bar come off (they are cast from their stances now).
## Returns true if anything changed.
func place_stances(trees: Array, primary: String, is_bending: Callable) -> bool:
	var changed_any := false
	if not _auto_placed.has(&"stances") and not trees.is_empty():
		for pg in pages:
			for i in SLOT_COUNT:
				if pg[i] != &"" and not is_item_slot(pg[i]) and not is_stance_slot(pg[i]) and is_bending.call(pg[i]):
					pg[i] = &""
		_auto_placed[&"stances"] = true
		changed_any = true
	var order: Array = trees.duplicate()
	if order.has(primary):
		order.erase(primary)
		order.push_front(primary)
	for tree in order:
		var key := StringName("stance:" + tree)
		if _auto_placed.has(key):
			continue
		_auto_placed[key] = true
		changed_any = true
		var already := false
		for pg in pages:
			for e in pg:
				if is_stance_slot(e) and stance_of(e)[0] == tree:
					already = true
		if already:
			continue
		if tree == primary or (primary == "" and tree == order[0]):
			var displaced: Array = []
			for n in range(1, 6):
				if pages[0][n - 1] != &"":
					displaced.append(pages[0][n - 1])
				pages[0][n - 1] = stance_entry(tree, n)
			for e in displaced:
				_put_in_first_empty(e)
		else:
			for n in range(1, 6):
				_put_in_first_empty(stance_entry(tree, n))
	if changed_any:
		changed.emit()
	return changed_any


func _put_in_first_empty(entry: StringName) -> void:
	for pg in pages:
		var i: int = pg.find(&"")
		if i >= 0:
			pg[i] = entry
			return
