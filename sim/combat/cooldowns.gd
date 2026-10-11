class_name Cooldowns
extends RefCounted
## One actor's timers: per-ability cooldowns, the global cooldown (GCD) and the
## step cooldown. Times are absolute sim-clock seconds passed in by the caller,
## so state is plain data that can be replicated and tested deterministically.
## Each timer remembers its start and duration so the UI can draw sweeps.

## Absorbs float drift from accumulating fixed ticks (e.g. 20 × 0.05 ≠ 1.0).
const EPSILON := 0.000001

var _abilities := {} # StringName -> Vector2(start, duration)
var _gcd := Vector2.ZERO
var _step := Vector2.ZERO


## Whether `ability` is off its own cooldown and, if it uses the GCD, off the GCD.
func can_use(ability: AbilityDef, now: float) -> bool:
	if ability.on_gcd and gcd_remaining(now) > 0.0:
		return false
	return ability_remaining(ability.cooldown_key(), now) <= 0.0


## Starts the ability's cooldown and, if it uses the GCD, the GCD.
func trigger(ability: AbilityDef, now: float, gcd_seconds: float) -> void:
	if ability.cooldown_seconds > 0.0:
		_abilities[ability.cooldown_key()] = Vector2(now, ability.cooldown_seconds)
	if ability.on_gcd and gcd_seconds > 0.0:
		_gcd = Vector2(now, gcd_seconds)


func ability_remaining(id: StringName, now: float) -> float:
	return _remaining(_abilities.get(id, Vector2.ZERO), now)


## 1.0 right after use, falling to 0.0 when ready. For cooldown sweeps.
func ability_fraction(id: StringName, now: float) -> float:
	return _fraction(_abilities.get(id, Vector2.ZERO), now)


func gcd_remaining(now: float) -> float:
	return _remaining(_gcd, now)


func gcd_fraction(now: float) -> float:
	return _fraction(_gcd, now)


func can_step(now: float) -> bool:
	return step_remaining(now) <= 0.0


func trigger_step(now: float, duration: float) -> void:
	_step = Vector2(now, duration)


func step_remaining(now: float) -> float:
	return _remaining(_step, now)


## Plain-data form for replication.
func to_dict() -> Dictionary:
	var abilities := {}
	for id in _abilities:
		abilities[id] = [_abilities[id].x, _abilities[id].y]
	return {
		"abilities": abilities,
		"gcd": [_gcd.x, _gcd.y],
		"step": [_step.x, _step.y],
	}


static func from_dict(d: Dictionary) -> Cooldowns:
	var c := Cooldowns.new()
	var abilities: Dictionary = d.get("abilities", {})
	for id in abilities:
		c._abilities[StringName(id)] = Vector2(abilities[id][0], abilities[id][1])
	var gcd: Array = d.get("gcd", [0.0, 0.0])
	c._gcd = Vector2(gcd[0], gcd[1])
	var step: Array = d.get("step", [0.0, 0.0])
	c._step = Vector2(step[0], step[1])
	return c


static func _remaining(timer: Vector2, now: float) -> float:
	var r := timer.x + timer.y - now
	return r if r > EPSILON else 0.0


static func _fraction(timer: Vector2, now: float) -> float:
	if timer.y <= 0.0:
		return 0.0
	return clampf(_remaining(timer, now) / timer.y, 0.0, 1.0)
