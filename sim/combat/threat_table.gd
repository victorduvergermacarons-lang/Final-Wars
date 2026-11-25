class_name ThreatTable
extends RefCounted
## An enemy's threat list (WoW-style) and the target it is attacking.
##
## The target doesn't simply follow the most threat: another actor takes it over
## only once their threat is above the target's threat × `melee_overtake_percent`
## (110%) while within melee range of the enemy, or × `ranged_overtake_percent`
## (130%) farther away (CombatRules). A taunt makes the taunter the target and
## skips that check for `taunt_seconds` (forced). When the target leaves the table
## (dies, leaves the zone, the enemy leashes), the highest threat takes over. Ties
## go to whoever was added first, and the table changes only on the host's sim
## ticks, in a fixed order, so every peer agrees on the target.

var _threat := {} # actor id -> float, in insertion order
var _current := -1 # the actor being attacked (-1: none chosen yet)
var _forced_by := -1 # the taunter while a taunt forces the target
var _forced_until := 0.0 # sim time the forced target ends


func add(actor_id: int, amount: float) -> void:
	_threat[actor_id] = _threat.get(actor_id, 0.0) + maxf(amount, 0.0)


## Taunts: `actor_id`'s threat rises to the current top threat plus
## `lead_percent`, it becomes the target, and for `seconds` (from `now`) the enemy
## stays on it whatever the threat says.
func taunt(actor_id: int, lead_percent: float, now: float = 0.0, seconds: float = 0.0) -> void:
	var top_amount := 0.0
	for id in _threat:
		top_amount = maxf(top_amount, _threat[id])
	var amount := top_amount * (1.0 + lead_percent / 100.0)
	if amount <= top_amount:
		amount = top_amount + 1.0
	_threat[actor_id] = maxf(_threat.get(actor_id, 0.0), amount)
	_current = actor_id
	if seconds > 0.0:
		_forced_by = actor_id
		_forced_until = maxf(now + seconds, _forced_until if _forced_by == actor_id else 0.0)


func remove(actor_id: int) -> void:
	_threat.erase(actor_id)
	if actor_id == _forced_by:
		_forced_by = -1 # the taunter died or left: the forced time ends early
	if actor_id == _current:
		_current = -1


func clear() -> void:
	_threat.clear()
	_current = -1
	_forced_by = -1


func has(actor_id: int) -> bool:
	return _threat.has(actor_id)


func get_threat(actor_id: int) -> float:
	return _threat.get(actor_id, 0.0)


func is_empty() -> bool:
	return _threat.is_empty()


func ids() -> Array:
	return _threat.keys()


## The actor this enemy attacks, or -1 if the table is empty. Without a target yet
## (or once it left the table): the highest threat.
func target() -> int:
	if _current == -1 or not _threat.has(_current):
		_current = highest()
	return _current


## Whether a taunt still forces the target at `now`.
func is_forced(now: float) -> bool:
	return _forced_by != -1 and _threat.has(_forced_by) and now < _forced_until


## Actor id with the most threat (ties: added first), or -1 if empty.
func highest() -> int:
	var best := -1
	var best_amount := -1.0
	for id in _threat:
		if _threat[id] > best_amount:
			best = id
			best_amount = _threat[id]
	return best


## Re-picks the target (each tick, before the enemy acts). While forced by a taunt
## the taunter stays the target; otherwise another actor takes it only above the
## target's threat × the overtake percent: `melee_percent` if `in_melee.call(id)`,
## else `ranged_percent`. Of several, the most threat wins (ties: added first).
## Returns the target.
func update(now: float, melee_percent: float, ranged_percent: float, in_melee: Callable) -> int:
	if _forced_by != -1 and not is_forced(now):
		_forced_by = -1
	if _forced_by != -1:
		_current = _forced_by
		return _current
	var current := target()
	if current == -1:
		return -1
	var held: float = _threat[current]
	var best := current
	var best_amount := -1.0
	for id in _threat:
		if id == current:
			continue
		var amount: float = _threat[id]
		var percent := melee_percent if in_melee.call(id) else ranged_percent
		if amount > held * percent / 100.0 and amount > best_amount:
			best = id
			best_amount = amount
	_current = best
	return _current
