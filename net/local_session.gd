class_name LocalSession
extends Node
## Solo play: runs the authoritative WorldSim in-process and feeds it the local
## player's intents. The networked sessions (step 9) expose the same API, so the
## view, input and HUD never know which one they're talking to.

signal events_received(events: Array)

var world: WorldSim
var local_hero_id: int = -1
var _accumulator := 0.0


func start(zone: ZoneDef, rules: CombatRules, hero_def: HeroDef, rng_seed: int = 0) -> void:
	world = WorldSim.new(zone, rules, rng_seed)
	local_hero_id = world.add_hero(hero_def).id


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
		if not events.is_empty():
			events_received.emit(events)


## Called after every sim tick (the host broadcasts state here).
func _on_tick(_events: Array) -> void:
	pass


# --- Read-only view of the world for view/input/UI --------------------------------

func grid() -> GridModel:
	return world.grid


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
	var ids := world.ctx.actors.keys()
	ids.sort()
	for id in ids:
		out.append(world.ctx.actors[id])
	return out


## Projectiles in flight as plain data (Projectile.to_dict).
func projectiles() -> Array:
	return world.projectiles().map(func(p): return p.to_dict())


func get_actor(id: int) -> Actor:
	return world.get_actor(id)


func local_hero() -> Hero:
	return world.get_actor(local_hero_id) as Hero
