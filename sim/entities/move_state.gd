class_name MoveState
extends RefCounted
## The tile-to-tile walk an actor is currently making. The sim position is
## `to_tile` from the moment a step starts; the view uses `progress()` to glide.
##
## Step gating:
## - Out of combat: only the walk itself — a new step may start once the
##   previous one has arrived. No step cooldown.
## - In combat: the walk must have arrived AND the step cooldown must be ready.

var from_tile := Vector2i.ZERO
var to_tile := Vector2i.ZERO
var start_time := 0.0
var duration := 0.0


func _init(tile: Vector2i = Vector2i.ZERO) -> void:
	from_tile = tile
	to_tile = tile


func begin(to: Vector2i, now: float, walk_seconds: float) -> void:
	from_tile = to_tile
	to_tile = to
	start_time = now
	duration = walk_seconds


## Snap to a tile with no walk in progress (spawn, respawn, leash reset).
func place(tile: Vector2i) -> void:
	from_tile = tile
	to_tile = tile
	duration = 0.0


func is_moving(now: float) -> bool:
	return now + Cooldowns.EPSILON < start_time + duration


## 0.0 at from_tile, 1.0 at to_tile.
func progress(now: float) -> float:
	if duration <= 0.0:
		return 1.0
	return clampf((now - start_time) / duration, 0.0, 1.0)


func can_start_step(in_combat: bool, cooldowns: Cooldowns, now: float) -> bool:
	if is_moving(now):
		return false
	return cooldowns.can_step(now) if in_combat else true


func to_dict() -> Dictionary:
	return {"from": from_tile, "to": to_tile, "start": start_time, "duration": duration}


static func from_dict(d: Dictionary) -> MoveState:
	var m := MoveState.new()
	m.from_tile = d.get("from", Vector2i.ZERO)
	m.to_tile = d.get("to", Vector2i.ZERO)
	m.start_time = d.get("start", 0.0)
	m.duration = d.get("duration", 0.0)
	return m
