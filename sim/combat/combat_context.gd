class_name CombatContext
extends RefCounted
## Everything ability resolution needs to know about the world at one instant.
## WorldSim owns one and updates `now` every tick.

var grid: GridModel
var rules: CombatRules
var rng: RandomNumberGenerator
var now: float = 0.0
var actors := {} # id -> Actor
## Damage multiplier of the ability being resolved right now (e.g. Kindle), set by
## whoever resolves a cast, projectile or delayed hit; 1 otherwise.
var damage_bonus: float = 1.0
## Recent tiles of every actor, for the skillshot grace window:
## id -> [[time, tile], ...] (oldest first, ~0.5 s kept).
var recent_tiles := {}
const RECENT_SECONDS := 0.5


func _init(p_grid: GridModel, p_rules: CombatRules, p_rng: RandomNumberGenerator) -> void:
	grid = p_grid
	rules = p_rules
	rng = p_rng


func add_actor(actor: Actor) -> void:
	actors[actor.id] = actor


## Records where every actor is now (called once per tick).
func record_positions() -> void:
	for id in actors:
		var entries: Array = recent_tiles.get(id, [])
		entries.append([now, actors[id].tile()])
		while entries.size() > 1 and entries[0][0] < now - RECENT_SECONDS:
			entries.pop_front()
		recent_tiles[id] = entries


## Whether `actor` is on `tile` now or was at any moment in the last `window` seconds.
func was_on(actor: Actor, tile: Vector2i, window: float) -> bool:
	if actor.tile() == tile:
		return true
	if window <= 0.0:
		return false
	for e in recent_tiles.get(actor.id, []):
		if e[0] >= now - window - 0.0001 and e[1] == tile:
			return true
	return false


func get_actor(id: int) -> Actor:
	return actors.get(id)


## Living enemies whose threat table lists `actor_id`, in id order.
func enemies_fighting(actor_id: int) -> Array[Actor]:
	var out: Array[Actor] = []
	var ids := actors.keys()
	ids.sort()
	for id in ids:
		var a: Actor = actors[id]
		if a.alive and a.threat != null and a.threat.has(actor_id):
			out.append(a)
	return out
