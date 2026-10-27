class_name BossEncounter
extends RefCounted
## Runs a BossEncounterDef in one zone (a dungeon copy): phases from the boss's
## health, the heart's pulses (adds, greyed tiles), the enrage, the heart's
## vulnerability, the end of the fight, and the reset to the current phase's start
## after a party wipe. Called every tick by its WorldSim, after the enemies act.

var def: BossEncounterDef
var phase := 1
var defeated := false
var boss_id := -1
var heart_id := -1
var _next_pulse := 0.0
var _adds: Array[int] = []
## Set by a wipe: until the boss is fighting again, its health stays at its phase's start.
var _resetting := false


func _init(p_def: BossEncounterDef, sim: WorldSim) -> void:
	def = p_def
	for e in sim.enemies():
		if def.boss != null and e.def.id == def.boss.id:
			boss_id = e.id
		elif def.heart != null and e.def.id == def.heart.id:
			heart_id = e.id


func boss(sim: WorldSim) -> Enemy:
	return sim.get_actor(boss_id) as Enemy


func heart(sim: WorldSim) -> Enemy:
	return sim.get_actor(heart_id) as Enemy


func is_fighting(sim: WorldSim) -> bool:
	var b := boss(sim)
	return b != null and b.alive and b.state == Enemy.State.COMBAT


func update(sim: WorldSim) -> void:
	var b := boss(sim)
	var h := heart(sim)
	if defeated or b == null or h == null:
		return
	h.invulnerable = phase < 3
	b.min_hp = maxf(roundf(b.stats.hp * def.boss_floor), 1.0) if h.alive else 0.0
	if not h.alive:
		_victory(sim, b, h)
		return
	if not is_fighting(sim):
		# Waiting, or walking home after a wipe: back to its phase's starting health.
		if _resetting or phase > 1:
			b.hp = minf(b.hp, roundf(b.stats.hp * def.phase_start(phase)))
			h.hp = h.stats.hp
		_join_heart(h, b, false)
		return
	_resetting = false
	_join_heart(h, b, true)
	if phase == 3 and def.enrage_buff != null and not b.buffs.has(def.enrage_buff.id, sim.now):
		b.buffs.apply(def.enrage_buff, sim.now, 0.0, b.id, {"duration": 3600.0})
	# Phases go by the boss's health.
	while phase < 3 and b.hp <= b.stats.hp * def.phase_at[phase - 1] + 0.01:
		phase += 1
		_next_pulse = sim.now + 2.0
		sim.emit({"type": "boss_phase", "source": b.id, "phase": phase})
		if phase == 3 and def.enrage_buff != null:
			b.buffs.apply(def.enrage_buff, sim.now, 0.0, b.id, {"duration": 3600.0})
			sim.emit({"type": "enrage", "source": b.id, "target": b.id, "buff": def.enrage_buff.id})
	var every: float = def.for_phase(def.pulse_seconds, phase, 0.0)
	if every > 0.0 and sim.now >= _next_pulse:
		_next_pulse = sim.now + every
		_pulse(sim, b, h)
	_adds = _adds.filter(func(id): return sim.get_actor(id) != null and sim.get_actor(id).alive)


## The heart fights alongside the boss (in combat while it is, out when it isn't).
func _join_heart(h: Enemy, b: Enemy, fighting: bool) -> void:
	if fighting:
		h.state = Enemy.State.COMBAT
		for id in b.threat.ids():
			if not h.threat.ids().has(id):
				h.threat.add(id, 0.0)
		h.combat_until = b.combat_until
	else:
		h.state = Enemy.State.IDLE
		h.threat.clear()
		h.combat_until = -1.0


func _pulse(sim: WorldSim, b: Enemy, h: Enemy) -> void:
	var called: Array[int] = []
	var n: int = def.for_phase(def.adds_per_pulse, phase, 0)
	for i in n:
		if def.adds == null or _adds.size() >= def.max_adds:
			break
		var tile := sim.find_free_tile_near(h.tile() + Vector2i(0, 2))
		var add := sim.add_enemy(def.adds, tile)
		add.temporary = true
		add.level = def.adds.level
		add.set_party_size(sim.heroes().size(), sim.rules)
		add.state = Enemy.State.COMBAT
		add.home_tile = tile
		var top := b.threat.top()
		if top >= 0:
			add.threat.add(top, 0.0)
		_adds.append(add.id)
		called.append(add.id)
	var tiles := _grey_tiles(sim, def.for_phase(def.grey_tiles_per_pulse, phase, 0))
	if not tiles.is_empty() and def.grey_zone != null and not def.grey_zone.effects.is_empty():
		var fx := def.grey_zone.effects[0]
		sim.add_ground_zone(h.id, tiles, def.grey_zone, fx.zone_ability, maxf(fx.zone_tick_seconds, 0.1),
				sim.now + def.grey_seconds)
	sim.emit({"type": "heart_pulse", "source": h.id, "phase": phase, "adds": called, "tiles": tiles})


## Free walkable tiles near the living heroes, picked at random.
func _grey_tiles(sim: WorldSim, count: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var pool: Array[Vector2i] = []
	for hero in sim.heroes():
		if not hero.alive:
			continue
		for dy in range(-2, 3):
			for dx in range(-2, 3):
				var t := hero.tile() + Vector2i(dx, dy)
				if sim.grid.in_bounds(t) and sim.grid.is_walkable(t) and not pool.has(t):
					pool.append(t)
	while out.size() < count and not pool.is_empty():
		out.append(pool.pop_at(sim.ctx.rng.randi_range(0, pool.size() - 1)))
	return out


## The heart is broken: the boss collapses (its fighters get the kill), the adds
## and greyed tiles go, and the victory NPC comes in.
func _victory(sim: WorldSim, b: Enemy, h: Enemy) -> void:
	defeated = true
	b.min_hp = 0.0
	if b.alive:
		var events: Array[Dictionary] = []
		AbilityResolver.deal_damage(sim.ctx, null, b, &"grey_heart_break", b.hp + 1.0, false, events)
		sim._emit_resolved(events)
	for id in _adds:
		var add := sim.get_actor(id) as Enemy
		if add != null and add.alive:
			add.die()
			add.respawn_at = sim.now
	_adds.clear()
	sim.remove_ground_zones_from(h.id)
	if def.victory_npc != null:
		sim.add_npc(def.victory_npc, def.victory_tile, Vector2i.DOWN)
	sim.emit({"type": "boss_defeated", "source": b.id, "heart": h.id})


## A party wipe: the boss goes back to the start of its current phase (not full
## health), the heart heals, adds and greyed tiles go.
func on_wipe(sim: WorldSim) -> void:
	if defeated:
		return
	_resetting = true
	var b := boss(sim)
	var h := heart(sim)
	for id in _adds:
		var add := sim.get_actor(id) as Enemy
		if add != null and add.alive:
			add.die()
			add.respawn_at = sim.now
	_adds.clear()
	if h != null:
		sim.remove_ground_zones_from(h.id)
		h.hp = h.stats.hp
	if b != null:
		b.hp = roundf(b.stats.hp * def.phase_start(phase))
	sim.emit({"type": "boss_reset", "source": boss_id, "phase": phase})
