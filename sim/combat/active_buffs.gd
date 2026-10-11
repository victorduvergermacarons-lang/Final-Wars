class_name ActiveBuffs
extends RefCounted
## Buffs currently on one actor, with their expiry on the sim clock.

var _active := {} # StringName -> {"def": BuffDef, "expires": float}


## Applies or refreshes `buff`.
func apply(buff: BuffDef, now: float) -> void:
	_active[buff.id] = {"def": buff, "expires": now + buff.duration_seconds}


func remove(id: StringName) -> void:
	_active.erase(id)


func clear() -> void:
	_active.clear()


func has(id: StringName, now: float) -> bool:
	return _active.has(id) and _active[id].expires > now + Cooldowns.EPSILON


func remaining(id: StringName, now: float) -> float:
	return maxf(_active[id].expires - now, 0.0) if has(id, now) else 0.0


## Drops expired buffs. Returns the ids removed.
func expire(now: float) -> Array[StringName]:
	var gone: Array[StringName] = []
	for id in _active.keys():
		if not has(id, now):
			gone.append(id)
	for id in gone:
		_active.erase(id)
	return gone


## `stats` with every active buff applied: all flat bonuses, then all multipliers.
func modify(stats: StatBlock, now: float) -> StatBlock:
	var out := stats.copy()
	var mods: Array[StatModifier] = []
	for id in _active:
		if has(id, now):
			mods.append_array(_active[id].def.modifiers)
	for m in mods:
		out.set_stat(m.stat, out.get_stat(m.stat) + m.flat)
	for m in mods:
		out.set_stat(m.stat, out.get_stat(m.stat) * m.multiplier)
	return out


## Plain data for replication: {id: expires}.
func to_dict() -> Dictionary:
	var d := {}
	for id in _active:
		d[id] = _active[id].expires
	return d
