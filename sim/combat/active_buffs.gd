class_name ActiveBuffs
extends RefCounted
## Buffs currently on one actor, with their expiry on the sim clock.

var _active := {} # StringName -> {"def", "expires", "heal_per_tick", "next_tick", "source"}


## Applies or refreshes `buff`. Heal-over-time buffs pass the healing per tick and
## who cast it.
func apply(buff: BuffDef, now: float, heal_per_tick: float = 0.0, source: int = -1) -> void:
	_active[buff.id] = {"def": buff, "expires": now + buff.duration_seconds,
			"heal_per_tick": heal_per_tick, "next_tick": now + buff.tick_seconds, "source": source}


## Restores a buff with a known expiry time (client mirrors).
func set_expiry(buff: BuffDef, expires: float) -> void:
	_active[buff.id] = {"def": buff, "expires": expires, "heal_per_tick": 0.0, "next_tick": INF, "source": -1}


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


## Product of active step-cooldown multipliers (slows).
func step_multiplier(now: float) -> float:
	var m := 1.0
	for id in _active:
		if has(id, now):
			m *= _active[id].def.step_cooldown_multiplier
	return m


func is_rooted(now: float) -> bool:
	for id in _active:
		if has(id, now) and _active[id].def.roots:
			return true
	return false


## Heal-over-time ticks that are due: [{"buff", "amount", "source"}]. Advances them.
func due_heals(now: float) -> Array:
	var out: Array = []
	for id in _active:
		var b: Dictionary = _active[id]
		while b.heal_per_tick > 0.0 and b.next_tick <= now + Cooldowns.EPSILON \
				and b.next_tick <= b.expires + Cooldowns.EPSILON:
			out.append({"buff": id, "amount": b.heal_per_tick, "source": b.source})
			b.next_tick += b.def.tick_seconds
	return out


## Active buff ids with whether each is a debuff, for frames: [[id, is_debuff, remaining]].
func summary(now: float) -> Array:
	var out: Array = []
	for id in _active:
		if has(id, now):
			out.append([id, _active[id].def.is_debuff, _active[id].expires - now])
	return out
