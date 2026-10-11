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
		"cast":
			var ability = raw.get("ability")
			if typeof(ability) != TYPE_STRING and typeof(ability) != TYPE_STRING_NAME:
				return {}
			if typeof(raw.get("target", -1)) != TYPE_INT:
				return {}
			out.ability = StringName(ability)
			out.target = raw.get("target", -1)
		"release":
			pass
		"equip":
			var item = raw.get("item")
			if typeof(item) != TYPE_STRING and typeof(item) != TYPE_STRING_NAME:
				return {}
			out.item = StringName(item)
		"unequip":
			if typeof(raw.get("slot")) != TYPE_INT:
				return {}
			out.slot = raw.slot
		_:
			return {}
	return out
