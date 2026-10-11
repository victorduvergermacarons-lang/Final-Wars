class_name World
extends RefCounted
## The whole game world on the host: one WorldSim per zone, stepped together on a
## shared clock, with heroes moving between zones through exit tiles.
## Events carry a "zone" key so each player only receives their own zone's events.

var rules: CombatRules
var start_zone: StringName
## One-time world events (saved by the host).
var world_flags := {}
var ids := IdSource.new()

var _zones := {} # id -> WorldSim
var _hero_zone := {} # hero id -> zone id
var _last_tile := {} # hero id -> tile last tick (exits trigger on arrival)


func _init(zone_defs: Array, p_rules: CombatRules, rng_seed: int, p_start_zone: StringName) -> void:
	rules = p_rules
	start_zone = p_start_zone
	var i := 0
	for z in zone_defs:
		_zones[z.id] = WorldSim.new(z, rules, rng_seed + i, ids)
		i += 1


var now: float:
	get:
		return _zones[start_zone].now


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


func _handle_exits() -> Array[Dictionary]:
	var events: Array[Dictionary] = []
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
		var ack := sim.intent_ack(hero.id)
		sim.transfer_out(hero.id)
		_zones[exit.to_zone].transfer_in(hero, exit.to_tile, ack)
		_hero_zone[hero.id] = exit.to_zone
		_last_tile[hero.id] = hero.tile()
		events.append({"type": "zone_change", "target": hero.id, "from": sim.zone.id,
				"to": exit.to_zone, "zone": exit.to_zone})
	return events


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
