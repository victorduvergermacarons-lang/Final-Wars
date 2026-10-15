class_name World
extends RefCounted
## The whole game world on the host: one WorldSim per zone, stepped together on a
## shared clock, with heroes moving between zones through exit tiles.
## Events carry a "zone" key so each player only receives their own zone's events.

var rules: CombatRules
var start_zone: StringName
## One-time world events (saved by the host). Shared by every zone's WorldSim.
var world_flags := {}:
	set(value):
		world_flags = value
		for sim in _zones.values():
			sim.world_flags = value
var ids := IdSource.new()

var _zones := {} # id -> WorldSim
var _hero_zone := {} # hero id -> zone id
var _last_tile := {} # hero id -> tile last tick (exits trigger on arrival)


## `quests`: id -> QuestDef, shared by every zone.
func _init(zone_defs: Array, p_rules: CombatRules, rng_seed: int, p_start_zone: StringName,
		quests: Dictionary = {}) -> void:
	rules = p_rules
	start_zone = p_start_zone
	var i := 0
	for z in zone_defs:
		var sim := WorldSim.new(z, rules, rng_seed + i, ids)
		sim.quests = quests
		sim.world_flags = world_flags
		_zones[z.id] = sim
		i += 1


var now: float:
	get:
		return _zones[start_zone].now


## Allows the debug console in every zone (`content`: lookup tables by id), or
## refuses it again (null).
func enable_debug(content) -> void:
	for id in _zones:
		_zones[id].debug_content = content


func zone(id: StringName) -> WorldSim:
	return _zones.get(id)


func zone_ids() -> Array:
	var out := _zones.keys()
	out.sort()
	return out


## The zone a hero is in, or null.
func zone_of(hero_id: int) -> WorldSim:
	return _zones.get(_hero_zone.get(hero_id, &""))


## Brings a saved character into the world (in the start zone unless told otherwise).
func add_saved_hero(data: Dictionary, content, zone_id: StringName = &"") -> Hero:
	var z: StringName = zone_id if zone_id != &"" else start_zone
	var hero: Hero = _zones[z].add_saved_hero(data, content)
	_hero_zone[hero.id] = z
	return hero


func remove_hero(hero_id: int) -> void:
	var sim := zone_of(hero_id)
	if sim != null:
		sim.remove_hero(hero_id)
	_hero_zone.erase(hero_id)
	_last_tile.erase(hero_id)


func submit(hero_id: int, intent: Dictionary) -> void:
	var sim := zone_of(hero_id)
	if sim != null:
		sim.submit(hero_id, intent)


func intent_ack(hero_id: int) -> int:
	var sim := zone_of(hero_id)
	return sim.intent_ack(hero_id) if sim != null else 0


## Advances every zone one tick, then moves heroes who arrived on an exit.
func step() -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	for id in zone_ids():
		for e in _zones[id].step():
			e.zone = id
			events.append(e)
	events.append_array(_handle_exits())
	return events


func advance(seconds: float) -> Array[Dictionary]:
	var all: Array[Dictionary] = []
	for i in roundi(seconds / rules.tick_seconds):
		all.append_array(step())
	return all


## Moves a hero to `tile` in zone `zone_id` (exits use this).
func move_hero(hero_id: int, zone_id: StringName, tile: Vector2i) -> void:
	var sim := zone_of(hero_id)
	if sim == null or not _zones.has(zone_id):
		return
	var ack := sim.intent_ack(hero_id)
	var hero := sim.transfer_out(hero_id)
	_zones[zone_id].transfer_in(hero, tile, ack)
	_hero_zone[hero_id] = zone_id
	_last_tile[hero_id] = hero.tile()


func _handle_exits() -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	for id in zone_ids():
		var sim: WorldSim = _zones[id]
		for req in sim.take_edge_requests():
			events.append_array(_leave_by_edge(sim, req[0], req[1]))
	for hero in heroes():
		var sim := zone_of(hero.id)
		var tile := hero.tile()
		var arrived: bool = _last_tile.get(hero.id) != tile
		_last_tile[hero.id] = tile
		if not arrived or not hero.alive:
			continue
		var exit := sim.exit_at(tile)
		if exit == null or not _zones.has(exit.to_zone):
			continue
		if hero.in_combat(now):
			events.append({"type": "rejected", "target": hero.id, "intent": "exit",
					"reason": "in_combat", "zone": sim.zone.id})
			continue
		move_hero(hero.id, exit.to_zone, exit.to_tile)
		events.append({"type": "zone_change", "target": hero.id, "from": sim.zone.id,
				"to": exit.to_zone, "zone": exit.to_zone})
	return events


## Moves a hero who stepped off `sim`'s map through `edge` to the matching edge
## tile of the next zone (or the nearest free tile along that edge).
func _leave_by_edge(sim: WorldSim, hero_id: int, edge: ZoneEdge) -> Array[Dictionary]:
	var hero := sim.get_actor(hero_id) as Hero
	var dest: WorldSim = _zones.get(edge.to_zone)
	if hero == null or dest == null:
		return []
	var target := edge.arrival(hero.tile(), Vector2i(dest.grid.width, dest.grid.depth))
	for k in [0, 1, -1, 2, -2]:
		var t: Vector2i = target + edge.along() * k
		if dest.grid.in_bounds(t) and dest.grid.is_walkable(t) and not dest.is_occupied(t):
			var from := sim.zone.id
			move_hero(hero_id, edge.to_zone, t)
			return [{"type": "zone_change", "target": hero_id, "from": from, "to": edge.to_zone,
					"zone": edge.to_zone}]
	return [{"type": "rejected", "target": hero_id, "intent": "step", "reason": "blocked", "zone": sim.zone.id}]


## Every hero in every zone, by id.
func heroes() -> Array[Hero]:
	var out: Array[Hero] = []
	for id in zone_ids():
		out.append_array(_zones[id].heroes())
	out.sort_custom(func(a, b): return a.id < b.id)
	return out


## Every enemy in every zone.
func enemies() -> Array[Enemy]:
	var out: Array[Enemy] = []
	for id in zone_ids():
		out.append_array(_zones[id].enemies())
	return out


func get_actor(id: int) -> Actor:
	for z in _zones.values():
		var a: Actor = z.get_actor(id)
		if a != null:
			return a
	return null
