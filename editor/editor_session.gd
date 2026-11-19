class_name EditorSession
extends Node
## The map editor's stand-in for a play session: one zone, never ticked, so its
## enemies and people stand frozen where they spawn, and no hero. It offers the
## read API WorldView draws from (the same as LocalSession's).

signal events_received(events: Array)
## Never emitted: the editor stays on one map. (WorldView doesn't listen to it.)
signal zone_changed(zone: ZoneDef)

var sim: WorldSim
var local_hero_id := -1


func start(zone: ZoneDef, rules: CombatRules) -> void:
	sim = WorldSim.new(zone, rules, 0)


func grid() -> GridModel:
	return sim.grid


func zone() -> ZoneDef:
	return sim.zone


func zone_sim() -> WorldSim:
	return sim


func rules() -> CombatRules:
	return sim.rules


func now() -> float:
	return sim.now


func render_time() -> float:
	return sim.now


func actors() -> Array[Actor]:
	var out: Array[Actor] = []
	var ids := sim.ctx.actors.keys()
	ids.sort()
	for id in ids:
		out.append(sim.ctx.actors[id])
	return out


func get_actor(id: int) -> Actor:
	return sim.get_actor(id)


func local_hero() -> Hero:
	return null


func projectiles() -> Array:
	return []


func way_out() -> Variant:
	return null


func telegraphs() -> Array:
	return []


func ground_zones() -> Array:
	return []


func world_flags() -> Dictionary:
	return {}


func send_intent(_intent: Dictionary) -> void:
	pass
