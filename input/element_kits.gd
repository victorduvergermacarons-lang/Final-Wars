class_name ElementKits
extends RefCounted
## The Hades-style button layouts (2026-11-22): what X, Y, A and B do for each
## element and mode, and the weapon on X. Read from content/kits/element_kits.json
## (see its "about"); client-side only: the host still checks every cast.

const PATH := "res://content/kits/element_kits.json"
const BUTTONS := ["X", "Y", "A", "B"]

static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		var f := FileAccess.open(PATH, FileAccess.READ)
		var parsed = JSON.parse_string(f.get_as_text()) if f != null else null
		_data = parsed if parsed is Dictionary else {"elements": {}, "weapons": {}}
	return _data


## The modes of `element` (["Water", "Ice"]), [] without a kit.
static func modes(element: StringName) -> Array:
	return data().elements.get(String(element), {}).get("modes", [])


## What button `slot` (0 X, 1 Y, 2 A, 3 B) does for `hero` in `mode` (an index in
## modes): {"tap", "hold", "combo", "charge", "in_front", "weapon": bool} with
## AbilityDefs (missing keys: nothing), or {} if the kit doesn't cover it (the
## wheel's own slot is used then).
static func entry(hero: Hero, slot: int, mode: int) -> Dictionary:
	if hero == null:
		return {}
	var raw: Dictionary = {}
	var weapon := false
	if slot == 0:
		var tree := weapon_tree(hero)
		raw = data().weapons.get(tree, {})
		weapon = not raw.is_empty()
	else:
		var kit: Dictionary = data().elements.get(String(hero.element), {})
		var names: Array = kit.get("modes", [])
		if names.is_empty():
			return {}
		raw = kit.get(names[clampi(mode, 0, names.size() - 1)], {}).get(BUTTONS[slot], {})
	if raw.is_empty():
		return {}
	var out := {"weapon": weapon, "in_front": bool(raw.get("in_front", false))}
	for key in ["tap", "hold", "charge"]:
		var a: AbilityDef = ContentDB.abilities.get(StringName(raw.get(key, "")))
		if a != null:
			out[key] = a
	var combo: Array[AbilityDef] = []
	for id in raw.get("combo", []):
		var a: AbilityDef = ContentDB.abilities.get(StringName(id))
		if a != null:
			combo.append(a)
	if not combo.is_empty():
		out.combo = combo
	return out


## Seconds a button must be held for its "hold" ability.
static func hold_seconds(weapon: bool) -> float:
	var h: Dictionary = data().get("hold_seconds", {})
	return float(h.get("weapon" if weapon else "element", 2.0 if weapon else 1.0))


static func combo_reset_seconds() -> float:
	return float(data().get("combo_reset_seconds", 1.0))


## "Sword", "Bow" or "Hammer" for the weapon in hand, else "".
static func weapon_tree(hero: Hero) -> String:
	var w: ItemDef = hero.equipped_in(EquipSlot.Id.MAIN_HAND)
	return w.tree if w != null and w.tree in ["Sword", "Bow", "Hammer"] else ""


## Every ability in every kit (test characters master them).
static func all_ability_ids(element: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	var kit: Dictionary = data().elements.get(String(element), {})
	for mode in kit.get("modes", []):
		for b in kit.get(mode, {}).values():
			for key in ["tap", "hold", "charge"]:
				if b.has(key) and not out.has(StringName(b[key])):
					out.append(StringName(b[key]))
			for id in b.get("combo", []):
				if not out.has(StringName(id)):
					out.append(StringName(id))
	for w in data().weapons.values():
		for key in ["tap", "hold"]:
			if w.has(key) and not out.has(StringName(w[key])):
				out.append(StringName(w[key]))
	return out
