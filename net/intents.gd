class_name Intents
extends RefCounted
## Validates the shape of intents coming from players (possibly remote and
## untrusted) before they reach WorldSim. Rules are checked by WorldSim itself.


## Returns a clean intent, or {} if `raw` is malformed.
static func sanitize(raw: Variant) -> Dictionary:
	if typeof(raw) != TYPE_DICTIONARY:
		return {}
	var kind = raw.get("type")
	if typeof(kind) != TYPE_STRING and typeof(kind) != TYPE_STRING_NAME:
		return {}
	var out := {"type": String(kind)}
	if raw.has("seq"):
		if typeof(raw.seq) != TYPE_INT:
			return {}
		out.seq = raw.seq
	match out.type:
		"step":
			if typeof(raw.get("to")) != TYPE_VECTOR2I:
				return {}
			out.to = raw.to
		"face":
			if typeof(raw.get("dir")) != TYPE_VECTOR2I:
				return {}
			out.dir = raw.dir
		"cast":
			var ability = raw.get("ability")
			if typeof(ability) != TYPE_STRING and typeof(ability) != TYPE_STRING_NAME:
				return {}
			if typeof(raw.get("target", -1)) != TYPE_INT:
				return {}
			out.ability = StringName(ability)
			out.target = raw.get("target", -1)
			if raw.has("aim"):
				var aim = raw.aim
				if typeof(aim) == TYPE_VECTOR2I:
					aim = Vector2(aim)
				if typeof(aim) != TYPE_VECTOR2 or not aim.is_finite() or absf(aim.x) > 10000.0 or absf(aim.y) > 10000.0:
					return {}
				out.aim = aim
		"release":
			pass
		"talk":
			if not _ints(raw, out, ["npc"]):
				return {}
		"take_loot":
			if not _ints(raw, out, ["loot"]):
				return {}
		"use_item":
			if not _ints(raw, out, ["bag_index"]):
				return {}
		"buy":
			var item = raw.get("item")
			if typeof(item) != TYPE_STRING and typeof(item) != TYPE_STRING_NAME:
				return {}
			if not _ints(raw, out, ["npc", "count"]):
				return {}
			out.item = StringName(item)
		"sell":
			if not _ints(raw, out, ["npc", "bag_index", "count"]):
				return {}
		"equip":
			if not _ints(raw, out, ["bag_index"], ["slot"]):
				return {}
		"unequip":
			if not _ints(raw, out, ["slot"]):
				return {}
		"move_item":
			if not _ints(raw, out, ["from", "to"]):
				return {}
		"split_item":
			if not _ints(raw, out, ["index", "count"]):
				return {}
		"destroy_item":
			if not _ints(raw, out, ["index"]):
				return {}
		"learn":
			if not _ints(raw, out, [], ["bag_index", "slot"]) or (out.has("bag_index") == out.has("slot")):
				return {}
		"stop_learning":
			pass
		"debug":
			var line = raw.get("line")
			if typeof(line) != TYPE_STRING or line.length() > 200:
				return {}
			out.line = line
		"game_speed":
			var value = raw.get("value")
			if typeof(value) != TYPE_FLOAT and typeof(value) != TYPE_INT:
				return {}
			out.value = clampf(float(value), CombatRules.GAME_SPEED_MIN, CombatRules.GAME_SPEED_MAX)
		"timing_press":
			var at = raw.get("at")
			if (typeof(at) != TYPE_FLOAT and typeof(at) != TYPE_INT) or not is_finite(float(at)):
				return {}
			out.at = clampf(float(at), 0.0, 60.0)
		"accept_quest", "turn_in_quest", "abandon_quest":
			var quest = raw.get("quest")
			if typeof(quest) != TYPE_STRING and typeof(quest) != TYPE_STRING_NAME:
				return {}
			out.quest = StringName(quest)
			if out.type != "abandon_quest" and not _ints(raw, out, ["npc"], ["choice"]):
				return {}
		_:
			return {}
	return out


## Copies required (and optional, if present) integer fields; false if any is
## missing or not an int.
static func _ints(raw: Dictionary, out: Dictionary, required: Array, optional: Array = []) -> bool:
	for key in required:
		if typeof(raw.get(key)) != TYPE_INT:
			return false
		out[key] = raw[key]
	for key in optional:
		if raw.has(key):
			if typeof(raw[key]) != TYPE_INT:
				return false
			out[key] = raw[key]
	return true
