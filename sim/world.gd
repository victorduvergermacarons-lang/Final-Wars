class_name World
extends RefCounted
## The whole game world on the host: one WorldSim per zone, stepped together on a
## shared clock, with heroes moving between zones through exit tiles.
## Events carry a "zone" key so each player only receives their own zone's events.
##
## Dungeons (ZoneDef.dungeon) are instanced per party: none exists until the party
## enters, then the party gets its own copy (key "<zone>@<party>"), which closes
## after it has stood empty for rules.dungeon_close_seconds. Entering needs the
## dungeon's quest and a party of at least rules.min_dungeon_party() (3; 1 with the
## "testing" setting). Zones are found by key everywhere (a normal zone's key is its
## id); a WorldSim's `zone.id` stays the map's id (clients load that map).

var rules: CombatRules
var start_zone: StringName
## One-time world events (saved by the host). Shared by every zone's WorldSim.
var world_flags := {}:
	set(value):
		world_flags = value
		for sim in _zones.values():
			sim.world_flags = value
var ids := IdSource.new()

var _zones := {} # key -> WorldSim (a zone's key is its id; dungeon copies "<id>@<party>")
var _hero_zone := {} # hero id -> zone key
var _dungeon_defs := {} # id -> ZoneDef of each dungeon (instanced on entry)
var _quests := {}
var _debug_content = null
var _seed := 0
var _last_tile := {} # hero id -> tile last tick (exits trigger on arrival)
var _empty_since := {} # zone id -> sim time it was last seen without heroes


## `quests`: id -> QuestDef, shared by every zone.
func _init(zone_defs: Array, p_rules: CombatRules, rng_seed: int, p_start_zone: StringName,
		quests: Dictionary = {}) -> void:
	rules = p_rules
	start_zone = p_start_zone
	_quests = quests
	_seed = rng_seed
	var i := 0
	for z in zone_defs:
		if z.dungeon:
			_dungeon_defs[z.id] = z
			continue
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
## Debug builds also start with the dungeon "testing" setting on (parties of one).
func enable_debug(content) -> void:
	_debug_content = content
	for id in _zones:
		_zones[id].debug_content = content
	if content != null:
		rules.dungeon_testing = true


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


# --- Dungeons ----------------------------------------------------------------------

## Every connected player is one party (rule 11); a real party system would give
## each its own id, and so its own dungeon copies.
func party_of(_hero_id: int) -> StringName:
	return &"party"


func party_size(hero_id: int) -> int:
	var party := party_of(hero_id)
	return heroes().filter(func(h): return party_of(h.id) == party).size()


func is_dungeon(zone_id: StringName) -> bool:
	return _dungeon_defs.has(zone_id)


## The key of `hero_id`'s party's copy of dungeon `zone_id`.
func instance_key(zone_id: StringName, hero_id: int) -> StringName:
	return StringName("%s@%s" % [zone_id, party_of(hero_id)])


## Why `hero` can't enter dungeon `def` ("" = it can).
func dungeon_entry_problem(hero: Hero, def: ZoneDef) -> String:
	if def.requires_quest != &"" and not (QuestLog.is_active(hero, def.requires_quest) \
			or QuestLog.is_done(hero, def.requires_quest)):
		return "dungeon_needs_quest"
	if party_size(hero.id) < rules.min_dungeon_party():
		return "dungeon_party_too_small"
	return ""


## The party's copy of dungeon `def` (made on first entry, on the world's clock).
func dungeon_instance(def: ZoneDef, hero_id: int) -> WorldSim:
	var key := instance_key(def.id, hero_id)
	if _zones.has(key):
		return _zones[key]
	var sim := WorldSim.new(def, rules, _seed + 1000 + _zones.size(), ids)
	sim.key = key
	sim.quests = _quests
	sim.world_flags = world_flags
	sim.debug_content = _debug_content
	sim.sync_clock(_zones[start_zone].tick_count)
	_zones[key] = sim
	return sim


## Closes dungeon copies nobody has been in for rules.dungeon_close_seconds.
func _close_empty_dungeons() -> void:
	for key in zone_ids():
		var sim: WorldSim = _zones[key]
		if not sim.zone.dungeon or not sim.heroes().is_empty():
			continue
		if now - float(_empty_since.get(key, now)) >= rules.dungeon_close_seconds - Cooldowns.EPSILON:
			_zones.erase(key)
			_empty_since.erase(key)


## Takes `hero` into its party's copy of dungeon `def` at `tile`, or says why not.
func _enter_dungeon(sim: WorldSim, hero: Hero, def: ZoneDef, tile: Vector2i) -> Array[Dictionary]:
	var why := dungeon_entry_problem(hero, def)
	if why != "":
		return [{"type": "rejected", "target": hero.id, "intent": "exit", "reason": why,
				"need": rules.min_dungeon_party(), "zone": sim.key}]
	var inst := dungeon_instance(def, hero.id)
	var from := sim.key
	move_hero(hero.id, inst.key, tile)
	return [{"type": "zone_change", "target": hero.id, "from": from, "to": inst.key, "zone": inst.key},
			{"type": "dungeon_enter", "target": hero.id, "dungeon": def.id, "zone": inst.key}]


## Advances every zone one tick, then moves heroes who arrived on an exit.
## Zones empty of heroes for `rules.empty_zone_sleep_seconds` only advance their
## clock (WorldSim.skip_tick), so the CPU goes to the zones people are in.
func step() -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	for id in zone_ids():
		var sim: WorldSim = _zones[id]
		if is_asleep(id):
			sim.skip_tick()
			continue
		for e in sim.step():
			e.zone = id
			events.append(e)
	events.append_array(_handle_exits())
	_close_empty_dungeons()
	return events


## True while zone `id` sleeps: no heroes in it for the configured time. A hero
## arriving wakes it on the next tick.
func is_asleep(id: StringName) -> bool:
	var sim: WorldSim = _zones[id]
	if rules.empty_zone_sleep_seconds < 0.0 or not sim.heroes().is_empty():
		_empty_since.erase(id)
		return false
	if not _empty_since.has(id):
		_empty_since[id] = sim.now
	return sim.now - _empty_since[id] >= rules.empty_zone_sleep_seconds - Cooldowns.EPSILON


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
		for hero_id in sim.take_respawn_requests():
			events.append_array(_respawn_elsewhere(sim, hero_id))
		for req in sim.take_zone_requests():
			var dest: WorldSim = _zones.get(req[1])
			if dest == null and is_dungeon(req[1]): # debug `goto`: straight into the party's copy
				dest = dungeon_instance(_dungeon_defs[req[1]], req[0])
			if dest != null and sim.get_actor(req[0]) != null and dest != sim:
				var spawn: Vector2i = dest.zone.hero_spawns[0] if not dest.zone.hero_spawns.is_empty() else Vector2i.ZERO
				move_hero(req[0], dest.key, spawn)
				events.append({"type": "zone_change", "target": req[0], "from": sim.key, "to": dest.key,
						"zone": dest.key})
	for hero in heroes():
		var sim := zone_of(hero.id)
		var tile := hero.tile()
		var arrived: bool = _last_tile.get(hero.id) != tile
		_last_tile[hero.id] = tile
		if not arrived or not hero.alive:
			continue
		var exit := sim.exit_at(tile)
		if exit == null:
			continue
		if exit.to_zone == &"" or exit.to_zone == sim.zone.id:
			# A lift or a ladder within the same map: a short ride, not a new zone.
			hero.move.place(sim.find_free_tile_near(exit.to_tile))
			_last_tile[hero.id] = hero.tile()
			events.append({"type": "lift", "target": hero.id, "tile": hero.tile(), "zone": sim.key})
			continue
		if not _zones.has(exit.to_zone) and not is_dungeon(exit.to_zone):
			continue
		if hero.in_combat(now):
			events.append({"type": "rejected", "target": hero.id, "intent": "exit",
					"reason": "in_combat", "zone": sim.key})
			continue
		if is_dungeon(exit.to_zone):
			events.append_array(_enter_dungeon(sim, hero, _dungeon_defs[exit.to_zone], exit.to_tile))
			continue
		move_hero(hero.id, exit.to_zone, exit.to_tile)
		events.append({"type": "zone_change", "target": hero.id, "from": sim.key,
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
			var from := sim.key
			move_hero(hero_id, edge.to_zone, t)
			return [{"type": "zone_change", "target": hero_id, "from": from, "to": edge.to_zone,
					"zone": edge.to_zone}]
	return [{"type": "rejected", "target": hero_id, "intent": "step", "reason": "blocked", "zone": sim.key}]


## A hero released in a zone without its own graveyard respawns at the graveyard
## of the zone it names (ZoneDef.respawn_zone), e.g. the Crossing's shrine.
func _respawn_elsewhere(sim: WorldSim, hero_id: int) -> Array[Dictionary]:
	var dest: WorldSim = _zones.get(sim.zone.respawn_zone)
	if dest == null or sim.get_actor(hero_id) == null:
		return []
	var from := sim.key
	var spawn: Vector2i = dest.zone.hero_spawns[0] if not dest.zone.hero_spawns.is_empty() else Vector2i.ZERO
	move_hero(hero_id, dest.key, dest.nearest_graveyard(spawn))
	var hero := dest.get_actor(hero_id)
	return [{"type": "zone_change", "target": hero_id, "from": from, "to": dest.key, "zone": dest.key},
			{"type": "release", "target": hero_id, "tile": hero.tile(), "zone": dest.key}]


## How fast the sim clock should run against real time: the game speed
## (`rules.game_speed`, a test setting). The session that drives the ticks applies
## it; the sim itself only ever sees sim seconds.
func time_scale() -> float:
	return rules.game_speed


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
