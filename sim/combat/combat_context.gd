class_name CombatContext
extends RefCounted
## Everything ability resolution needs to know about the world at one instant.
## WorldSim owns one and updates `now` every tick.

var grid: GridModel
var rules: CombatRules
var rng: RandomNumberGenerator
var now: float = 0.0
var actors := {} # id -> Actor


func _init(p_grid: GridModel, p_rules: CombatRules, p_rng: RandomNumberGenerator) -> void:
	grid = p_grid
	rules = p_rules
	rng = p_rng


func add_actor(actor: Actor) -> void:
	actors[actor.id] = actor


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
