class_name Projectile
extends RefCounted
## A LINE ability in flight (e.g. Fireball). Its path is fixed at launch (terrain
## doesn't change); each tick WorldSim checks the tiles it has reached for victims.

var id: int = 0
var caster_id: int = 0
var ability: AbilityDef
var origin := Vector2i.ZERO
var dir := Vector2i.RIGHT
var path: Array[Vector2i] = []
var start_time: float = 0.0
var speed: float = 10.0
## Index of the last path tile already checked (-1 = none yet).
var checked: int = -1
## Milestone 3 skillshots: keep flying through units; ids already hit.
var pierce: bool = false
var hit_ids := {}
## Damage bonus fixed at launch (e.g. Kindle).
var damage_bonus: float = 1.0
## Every hit is a critical (a timing bar's critical success), fixed at launch.
var force_crit: bool = false
## Free movement (a PROJECTILE hitbox): flies from `from` along `dirv` (unit
## vector), `radius` round, for up to `max_dist` tiles (terrain already cut it).
var continuous := false
var from := Vector2.ZERO
var dirv := Vector2.RIGHT
var max_dist := 0.0
var radius := 0.25
## Distance flown at the last check (hits are swept between checks).
var checked_dist := 0.0


## Where a continuous projectile is at `now`.
func point_at(now: float) -> Vector2:
	return from + dirv * minf(distance_at(now), max_dist)


## How many tiles along the path it has travelled (fractional).
func distance_at(now: float) -> float:
	return maxf(now - start_time, 0.0) * speed


## Path index of the tile it is in now, or -1 while still on the caster's tile.
func tile_index_at(now: float) -> int:
	return mini(floori(distance_at(now) + 0.5) - 1, path.size() - 1)


## True once it has flown past the end of its path.
func is_spent(now: float) -> bool:
	if continuous:
		return distance_at(now) >= max_dist
	return distance_at(now) >= path.size() + 0.5


func to_dict() -> Dictionary:
	if continuous:
		return {"id": id, "source": caster_id, "ability": ability.id, "origin": origin, "from": from,
				"dirv": dirv, "length": max_dist, "start": start_time, "speed": speed, "end": from + dirv * max_dist}
	return {"id": id, "source": caster_id, "ability": ability.id, "origin": origin, "dir": dir,
			"length": path.size(), "start": start_time, "speed": speed,
			"end": path.back() if not path.is_empty() else origin}
