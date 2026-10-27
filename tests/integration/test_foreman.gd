extends GutTest
## The Foreman and the Grey Heart (the Silent Shaft's boss, BossEncounter) with
## the shipped content: three phases by the Foreman's health, the Heart's pulses
## (adds, greyed tiles), the enrage and the Heart's shield, the end of the fight,
## party-size scaling with 1 and 4 heroes, and a wipe sending the boss back to the
## start of its current phase.

const ContentDBScript := preload("res://autoload/content_db.gd")

var db
var rules: CombatRules
var sim: WorldSim
var heroes: Array[Hero] = []


func before_all() -> void:
	db = ContentDBScript.new()


func after_all() -> void:
	db.free()


func before_each() -> void:
	rules = db.rules.duplicate()
	sim = WorldSim.new(db.zones[&"silent_shaft"], rules, 7)
	heroes.clear()


## `n` very sturdy heroes in the chamber, in front of the Foreman.
func _party(n: int) -> void:
	var hd := HeroDef.new()
	hd.base_stats = StatBlock.make({Stat.Id.HP: 1.0e7, Stat.Id.MANA: 100, Stat.Id.JUMP: 2})
	for i in n:
		var h := sim.add_hero(hd)
		h.display_name = "H%d" % i
		h.move.place(sim.find_free_tile_near(Vector2i(52 + i, 15)))
		heroes.append(h)
	sim.step() # scaled for the party before the pull


func _enc() -> BossEncounter:
	return sim.encounter


func _boss() -> Enemy:
	return _enc().boss(sim)


func _heart() -> Enemy:
	return _enc().heart(sim)


## The party hits `target` for `amount` (split among them, so all are on its table).
func _hit(target: Enemy, amount: float) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	for h in heroes:
		AbilityResolver.deal_damage(sim.ctx, h, target, &"S01", amount / heroes.size(), false, events)
	sim._emit_resolved(events)
	return events


func _pull() -> void:
	_hit(_boss(), 1.0)
	_boss().state = Enemy.State.COMBAT
	sim.step()


func _to_fraction(f: float) -> Array[Dictionary]:
	var b := _boss()
	_hit(b, b.hp - roundf(b.stats.hp * f) + 1.0)
	return sim.advance(0.1)


func test_the_encounter_finds_its_boss_and_heart() -> void:
	assert_not_null(_enc())
	assert_eq(_boss().def.id, &"foreman")
	assert_eq(_heart().def.id, &"grey_heart")
	assert_true(_boss().def.elite and _boss().def.dungeon_boss)
	assert_true(_heart().def.immobile)
	assert_eq(_enc().phase, 1)


func _phases(n: int) -> void:
	_party(n)
	var b := _boss()
	var h := _heart()
	assert_eq(b.stats.hp, roundf(b.def.stats.hp * rules.party_hp_multiplier(n)), "boss health for %d" % n)
	assert_eq(h.stats.hp, roundf(h.def.stats.hp * rules.party_hp_multiplier(n)), "heart health for %d" % n)
	if n > 1:
		assert_gt(b.stats.hp, b.def.stats.hp, "a dungeon boss scales although it is an elite")
	assert_almost_eq(b.damage_scale, rules.party_damage_multiplier(n), 0.001)
	_pull()
	var heart_tile := h.tile()
	# Phase 1: the Heart can't be hurt and doesn't pulse.
	var events := _hit(h, 100.0)
	assert_true(events.any(func(e): return e.type == "immune"), "phase 1: the Heart is shielded")
	assert_eq(h.hp, h.stats.hp)
	events = sim.advance(12.0)
	assert_false(events.any(func(e): return e.type == "heart_pulse"), "no pulses in phase 1")
	# Phase 2 at 60%: pulses bring adds and grey the floor.
	events = _to_fraction(0.59)
	assert_eq(_enc().phase, 2, "phase 2 below 60%")
	assert_true(events.any(func(e): return e.type == "boss_phase" and e.phase == 2))
	events = sim.advance(2.5)
	var pulses := events.filter(func(e): return e.type == "heart_pulse")
	assert_eq(pulses.size(), 1, "the Heart pulses soon after phase 2 begins")
	assert_eq(pulses[0].adds.size(), 1, "a husk climbs out")
	assert_eq(pulses[0].tiles.size(), 6, "six tiles turn grey")
	assert_true(sim.ground_zones().size() > 0, "greyed tiles are ground zones")
	assert_eq(h.tile(), heart_tile, "the Heart never moves")
	events = _hit(h, 100.0)
	assert_true(events.any(func(e): return e.type == "immune"), "phase 2: still shielded")
	# Phase 3 at 25%: the Foreman enrages and the Heart opens.
	events = _to_fraction(0.24)
	assert_eq(_enc().phase, 3)
	assert_true(b.buffs.has(&"foreman_fury", sim.now), "enraged")
	assert_false(h.invulnerable, "the Heart can be hurt")
	events = sim.advance(10.0)
	var late := events.filter(func(e): return e.type == "heart_pulse")
	assert_false(late.is_empty(), "it keeps pulsing until it breaks")
	assert_true(late.all(func(e): return e.adds.is_empty() and e.tiles.size() == 8), "phase 3: grey ground only")
	# He can't be finished while the Heart beats.
	_hit(b, b.stats.hp)
	sim.step()
	assert_true(b.alive, "held up by the Heart")
	assert_eq(b.hp, roundf(b.stats.hp * 0.05), "at 5%")
	# Breaking the Heart ends it.
	_hit(h, h.hp + 1.0)
	events = sim.advance(0.1)
	assert_true(events.any(func(e): return e.type == "boss_defeated"))
	assert_false(b.alive, "the Foreman falls with his Heart")
	assert_true(events.any(func(e): return e.type == "kill" and e.enemy == &"foreman"), "the party gets the kill")
	assert_true(sim.npcs().any(func(npc): return npc.def.id == &"caedan_shaft"), "Caedan comes down")
	assert_true(sim.enemies().filter(func(e): return e.def.id == &"grey_husk" and e.alive).is_empty(), "adds gone")
	assert_eq(sim.ground_zones().size(), 0, "the grey fades")


func test_three_phases_with_one_hero() -> void:
	_phases(1)


func test_three_phases_with_four_heroes() -> void:
	_phases(4)


func test_greyed_tiles_slow_and_drain_mana() -> void:
	_party(1)
	_pull()
	_to_fraction(0.59)
	var h := heroes[0]
	h.mana = 100.0
	var tiles: Array = []
	for e in sim.advance(2.5):
		if e.type == "heart_pulse":
			tiles = e.tiles
	assert_false(tiles.is_empty())
	h.move.place(tiles[0])
	sim.advance(2.0)
	assert_true(h.buffs.has(&"greyed", sim.now), "greyed")
	assert_lt(h.mana, 100.0, "mana drains on the grey")
	assert_gt(h.buffs.step_multiplier(sim.now), 1.0, "and steps slow")


func test_a_wipe_resets_the_boss_to_its_phase_start() -> void:
	_party(2)
	_pull()
	_to_fraction(0.4)
	assert_eq(_enc().phase, 2)
	sim.advance(3.0) # a pulse: adds and grey tiles
	_hit(_heart(), 0.0)
	for h in heroes:
		h.die()
	var events := sim.advance(rules.wipe_respawn_seconds + 0.2)
	assert_true(events.any(func(e): return e.type == "party_wipe"))
	assert_true(events.any(func(e): return e.type == "wipe_respawn"))
	assert_true(events.any(func(e): return e.type == "boss_reset" and e.phase == 2))
	var b := _boss()
	assert_eq(_enc().phase, 2, "stays in phase 2")
	assert_eq(b.hp, roundf(b.stats.hp * 0.6), "back to the start of phase 2, not full health")
	assert_eq(_heart().hp, _heart().stats.hp)
	assert_true(sim.enemies().filter(func(e): return e.def.id == &"grey_husk" and e.alive).is_empty(), "adds gone")
	assert_eq(sim.ground_zones().size(), 0, "the grey is gone")
	for h in heroes:
		assert_true(h.alive)
		assert_lte(GridModel.distance(h.tile(), sim.zone.graveyards[0]), 2, "at the entrance")
	# Walking home after the wipe doesn't heal him past his phase.
	sim.advance(20.0)
	assert_eq(b.hp, roundf(b.stats.hp * 0.6))
	assert_eq(_enc().phase, 2)


func test_a_wipe_in_phase_one_resets_to_full() -> void:
	_party(1)
	_pull()
	_to_fraction(0.8)
	heroes[0].die()
	sim.advance(rules.wipe_respawn_seconds + 0.2)
	assert_eq(_boss().hp, _boss().stats.hp)
	assert_eq(_enc().phase, 1)


func test_the_foreman_has_a_tank_to_beat() -> void:
	# Threat decides whom he strikes: the hero with the most threat holds him.
	_party(2)
	var b := _boss()
	_pull()
	b.threat.add(heroes[1].id, 5000.0)
	assert_eq(b.threat.top(), heroes[1].id)
	var taunt: AbilityDef = db.abilities[&"E04"] # Seismic Stomp: top threat + 10%
	heroes[0].move.place(sim.find_free_tile_near(b.tile()))
	var events: Array[Dictionary] = []
	AbilityResolver.apply_effects(sim.ctx, heroes[0], taunt, b, events)
	assert_eq(b.threat.top(), heroes[0].id, "a taunt takes him")
