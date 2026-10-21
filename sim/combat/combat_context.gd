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
## The cast being resolved: aimed tile, its 8-way direction from the caster, and
## its tiles (area / line). Set by CastResolver.
var cast_aim := Vector2i.ZERO
var cast_dir := Vector2i.ZERO
var cast_tiles: Array = []
## Things only the world can do, queued during resolution and handled by WorldSim
## right after: {"type": "terrain"|"zone"|"counter", ...}.
var requests: Array = []
## Recent tiles of every actor, for the skillshot grace window:
## id -> [[time, tile], ...] (oldest first, ~0.5 s kept).
var recent_tiles := {}
const RECENT_SECONDS := 0.5


func _init(p_grid: GridModel, p_rules: CombatRules, p_rng: RandomNumberGenerator) -> void:
	grid = p_grid
	rules = p_rules
	rng = p_rng


## Set while a charge shoves units aside: which way (perpendicular to the lane) to
## push the unit being hit; zero lets the knockback pick a free side.
var push_side := Vector2i.ZERO
## Set with push_side (Searing Dive): the exact tiles a sideways shove moves the unit,
## to just outside the charge's lane, whatever its weight (0 = the effect's own).
var push_tiles := 0


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
	if actor.covers(tile):
		return true
	if window <= 0.0:
		return false
	for e in recent_tiles.get(actor.id, []):
		if e[0] >= now - window - 0.0001 and actor.footprint.has(tile - e[1]):
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
