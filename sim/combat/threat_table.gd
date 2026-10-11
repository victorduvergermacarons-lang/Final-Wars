class_name ThreatTable
extends RefCounted
## An enemy's threat list (WoW-style). The top entry is who it attacks.
## Ties go to whoever was added first, so every peer agrees on the target.

var _threat := {} # actor id -> float, in insertion order


func add(actor_id: int, amount: float) -> void:
	_threat[actor_id] = _threat.get(actor_id, 0.0) + maxf(amount, 0.0)


## Puts `actor_id` on top: the current top threat plus `lead_percent`.
func taunt(actor_id: int, lead_percent: float) -> void:
	var top_amount := 0.0
	for id in _threat:
		top_amount = maxf(top_amount, _threat[id])
	var target := top_amount * (1.0 + lead_percent / 100.0)
	if target <= top_amount:
		target = top_amount + 1.0
	_threat[actor_id] = maxf(_threat.get(actor_id, 0.0), target)


func remove(actor_id: int) -> void:
	_threat.erase(actor_id)


func clear() -> void:
	_threat.clear()


func has(actor_id: int) -> bool:
	return _threat.has(actor_id)


func get_threat(actor_id: int) -> float:
	return _threat.get(actor_id, 0.0)


func is_empty() -> bool:
	return _threat.is_empty()


func ids() -> Array:
	return _threat.keys()


## Actor id with the most threat, or -1 if empty.
func top() -> int:
	var best := -1
	var best_amount := -1.0
	for id in _threat:
		if _threat[id] > best_amount:
			best = id
			best_amount = _threat[id]
	return best
