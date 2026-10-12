class_name LocalSession
extends Node
## Solo play: runs the authoritative WorldSim in-process and feeds it the local
## player's intents. The networked sessions (step 9) expose the same API, so the
## view, input and HUD never know which one they're talking to.

signal events_received(events: Array)
## The local hero moved to another zone; the view should switch maps.
signal zone_changed(zone: ZoneDef)

var world: World
var local_hero_id: int = -1
var _accumulator := 0.0


var _zone_id: StringName = &""


## Starts the world (all zones) with the local player's saved character.
func start(zones: Array, start_zone: StringName, rules: CombatRules, character: Dictionary, rng_seed: int = 0) -> void:
	world = World.new(zones, rules, rng_seed, start_zone, ContentDB.quests)
	local_hero_id = world.add_saved_hero(character, ContentDB).id
	_zone_id = zone().id


## The zone the local hero is in.
func zone_sim() -> WorldSim:
	var sim := world.zone_of(local_hero_id)
	return sim if sim != null else world.zone(world.start_zone)


func zone() -> ZoneDef:
	return zone_sim().zone


func send_intent(intent: Dictionary) -> void:
	receive_intent(local_hero_id, intent)


## Every intent, local or remote, enters the world here: sanitized, then queued.
func receive_intent(hero_id: int, raw: Variant) -> void:
	var intent := Intents.sanitize(raw)
	if not intent.is_empty():
		world.submit(hero_id, intent)


func _physics_process(delta: float) -> void:
	if world == null:
		return
	_accumulator += delta
	var tick := world.rules.tick_seconds
	while _accumulator >= tick:
		_accumulator -= tick
		var events := world.step()
		_on_tick(events)
		if zone().id != _zone_id:
			_zone_id = zone().id
			zone_changed.emit(zone())
		var mine := events.filter(func(e): return e.get("zone", _zone_id) == _zone_id)
		if not mine.is_empty():
			events_received.emit(mine)


## Called after every sim tick (the host broadcasts state here).
func _on_tick(_events: Array) -> void:
	pass


# --- Read-only view of the world for view/input/UI --------------------------------

func grid() -> GridModel:
	return zone_sim().grid


func rules() -> CombatRules:
	return world.rules


## Sim time of the latest tick (use for rules: cooldowns, in-combat checks).
func now() -> float:
	return world.now


## Smooth time for drawing: the latest tick plus the time since it.
func render_time() -> float:
	return world.now + _accumulator


func actors() -> Array[Actor]:
	var out: Array[Actor] = []
	var actors_by_id: Dictionary = zone_sim().ctx.actors
	var ids := actors_by_id.keys()
	ids.sort()
	for id in ids:
		out.append(actors_by_id[id])
	return out


## Projectiles in flight as plain data (Projectile.to_dict).
func projectiles() -> Array:
	return zone_sim().projectiles().map(func(p): return p.to_dict())


## Loot waiting for the local hero (didn't fit in the bag).
func pending_loot() -> Array:
	return zone_sim().pending_loot_for(local_hero_id)


## Actors in the local hero's zone only.
func get_actor(id: int) -> Actor:
	return zone_sim().get_actor(id)


func local_hero() -> Hero:
	return zone_sim().get_actor(local_hero_id) as Hero
