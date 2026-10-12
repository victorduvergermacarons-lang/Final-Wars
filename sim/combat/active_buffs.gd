class_name ActiveBuffs
extends RefCounted
## Buffs currently on one actor, with their expiry on the sim clock. Besides stat
## modifiers a buff instance can carry periodic healing or damage, a shield (damage
## absorbed first), crowd control (stun, silence, sleep, root, slow), haste, damage
## multipliers and charges (see BuffDef).

## StringName -> {"def", "expires", "tick_amount", "tick_damage", "damage_type",
## "next_tick", "source", "shield", "charges"}
var _active := {}


## Applies or refreshes `buff`. Periodic buffs pass the amount per tick and who
## cast it; `opts` may set "duration", "tick_damage" (true = damage instead of
## healing), "damage_type", "shield".
func apply(buff: BuffDef, now: float, tick_amount: float = 0.0, source: int = -1, opts: Dictionary = {}) -> void:
	var duration: float = opts.get("duration", buff.duration_seconds)
	_active[buff.id] = {"def": buff, "expires": now + duration, "tick_amount": tick_amount,
			"tick_damage": opts.get("tick_damage", false), "damage_type": opts.get("damage_type", 0),
			"next_tick": now + buff.tick_seconds, "source": source, "shield": float(opts.get("shield", 0.0)),
			"charges": buff.charges}


## Restores a buff with a known expiry time (client mirrors).
func set_expiry(buff: BuffDef, expires: float) -> void:
	_active[buff.id] = {"def": buff, "expires": expires, "tick_amount": 0.0, "tick_damage": false,
			"damage_type": 0, "next_tick": INF, "source": -1, "shield": 0.0, "charges": 0}


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


func _active_defs(now: float) -> Array:
	var out: Array = []
	for id in _active:
		if has(id, now):
			out.append(_active[id].def)
	return out


## Product of active step-cooldown multipliers (slows, haste).
func step_multiplier(now: float) -> float:
	var m := 1.0
	for d in _active_defs(now):
		m *= d.step_cooldown_multiplier
	return m


## Product of active cooldown multipliers (haste).
func cooldown_multiplier(now: float) -> float:
	var m := 1.0
	for d in _active_defs(now):
		m *= d.cooldown_multiplier
	return m


func is_rooted(now: float) -> bool:
	return _active_defs(now).any(func(d): return d.roots)


func is_stunned(now: float) -> bool:
	return _active_defs(now).any(func(d): return d.stuns or d.sleeps)


func is_asleep(now: float) -> bool:
	return _active_defs(now).any(func(d): return d.sleeps)


func is_silenced(now: float) -> bool:
	return _active_defs(now).any(func(d): return d.silences)


## The first counter buff that answers a hit ({} if none): {"negate", "reflect",
## "ability"}. Uses a charge of negating buffs that have charges.
func counter_for(melee: bool, now: float) -> Dictionary:
	for id in _active.keys():
		var b: Dictionary = _active[id]
		var d: BuffDef = b.def
		if not has(id, now) or (d.melee_only and not melee):
			continue
		if not d.negate_hits and d.reflect_fraction <= 0.0 and d.counter_ability == null:
			continue
		if d.negate_hits and d.charges > 0:
			b.charges -= 1
			if b.charges <= 0:
				_active.erase(id)
		return {"negate": d.negate_hits, "reflect": d.reflect_fraction, "ability": d.counter_ability}
	return {}


## Damage taken wakes sleepers.
func wake() -> void:
	for id in _active.keys():
		if _active[id].def.sleeps:
			_active.erase(id)


## Multiplier for damage the owner deals with an ability of `tree`.
func damage_dealt_multiplier(tree: String, now: float) -> float:
	var m := 1.0
	for d in _active_defs(now):
		if d.affects_tree == "" or d.affects_tree == tree:
			m *= d.damage_dealt_multiplier
	return m


func damage_taken_multiplier(now: float) -> float:
	var m := 1.0
	for d in _active_defs(now):
		m *= d.damage_taken_multiplier
	return m


## Uses one charge of each charged buff that applies to an ability of `tree`
## (not free-step buffs); buffs out of charges end.
func consume_on_cast(tree: String, now: float) -> void:
	for id in _active.keys():
		var b: Dictionary = _active[id]
		var d: BuffDef = b.def
		if not has(id, now) or d.charges <= 0 or d.free_steps:
			continue
		if d.affects_tree != "" and d.affects_tree != tree:
			continue
		b.charges -= 1
		if b.charges <= 0:
			_active.erase(id)


## A step with no step cooldown, if a free-step buff has charges left (uses one).
func use_free_step(now: float) -> bool:
	for id in _active.keys():
		var b: Dictionary = _active[id]
		if has(id, now) and b.def.free_steps:
			if b.def.charges > 0:
				b.charges -= 1
				if b.charges <= 0:
					_active.erase(id)
			return true
	return false


## Soaks damage with shields (oldest first). Returns what gets through.
func absorb(amount: float) -> float:
	var left := amount
	for id in _active.keys():
		var b: Dictionary = _active[id]
		if left <= 0.0:
			break
		if b.shield > 0.0:
			var used := minf(b.shield, left)
			b.shield -= used
			left -= used
			if b.shield <= 0.0:
				_active.erase(id)
	return left


func shield_total() -> float:
	var t := 0.0
	for id in _active:
		t += _active[id].shield
	return t


## Periodic ticks that are due: [{"buff", "amount", "source", "damage", "damage_type"}].
## Advances them.
func due_ticks(now: float) -> Array:
	var out: Array = []
	for id in _active:
		var b: Dictionary = _active[id]
		while b.tick_amount > 0.0 and b.next_tick <= now + Cooldowns.EPSILON \
				and b.next_tick <= b.expires + Cooldowns.EPSILON:
			out.append({"buff": id, "amount": b.tick_amount, "source": b.source,
					"damage": b.tick_damage, "damage_type": b.damage_type})
			b.next_tick += b.def.tick_seconds
	return out


## Heal-over-time ticks only (older callers).
func due_heals(now: float) -> Array:
	return due_ticks(now).filter(func(t): return not t.damage)


## Active buff ids with whether each is a debuff, for frames: [[id, is_debuff, remaining]].
func summary(now: float) -> Array:
	var out: Array = []
	for id in _active:
		if has(id, now):
			out.append([id, _active[id].def.is_debuff, _active[id].expires - now])
	return out
