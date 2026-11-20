extends GutTest
## Duels, WoW rules: request, flag at the midpoint, countdown, a fight between the
## two only, the boundary (warning then forfeit), yield at 1 HP, cleanup, no duels in
## dungeons.

const LEGACY_HERO := preload("res://tests/fixtures/legacy_adventurer.tres")

var world: WorldSim
var pp: PartyPlayDef
var a: Hero
var b: Hero
var c: Hero


func before_each() -> void:
	pp = ContentDB.rules.party_play
	world = WorldSim.new(ContentDB.zones[&"greenfields"], ContentDB.rules, 5)
	for e in world.enemies():
		e.move.place(Vector2i(29, 29))
	a = world.add_hero(LEGACY_HERO)
	b = world.add_hero(LEGACY_HERO)
	c = world.add_hero(LEGACY_HERO)
	a.display_name = "Ana"
	b.display_name = "Bo"
	c.display_name = "Cy"
	a.move.place(Vector2i(10, 20))
	b.move.place(Vector2i(14, 20))
	c.move.place(Vector2i(12, 22))


func _start() -> Dictionary:
	world.submit(a.id, {"type": "duel_request", "target": b.id})
	world.step()
	var r: Dictionary = world.social_view(b.id).requests[0]
	assert_eq(r.kind, "duel")
	world.submit(b.id, {"type": "request_answer", "request": r.id, "accept": true})
	world.step()
	assert_eq(world.duels_view().size(), 1)
	return world.duels_view()[0]


func _hit(from: Actor, to: Actor, amount: float) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	AbilityResolver.deal_damage(world.ctx, from, to, &"test", amount, false, events)
	world._emit_resolved(events)
	return events


func test_flag_at_the_midpoint_then_a_countdown_before_the_fight() -> void:
	var d := _start()
	assert_eq(d.flag, Vector2(12, 20))
	assert_eq(d.state, "countdown")
	assert_false(a.is_hostile_to(b), "not before the countdown ends")
	world.advance(pp.duel_countdown + 0.1)
	assert_eq(world.duels_view()[0].state, "live")
	assert_true(a.is_hostile_to(b) and b.is_hostile_to(a))
	assert_false(a.is_ally_of(b))
	assert_false(a.is_hostile_to(c), "only each other")


func test_the_loser_yields_at_one_hp_without_dying() -> void:
	_start()
	world.advance(pp.duel_countdown + 0.1)
	_hit(a, b, 10000.0) # the yield settles the duel at once
	assert_true(b.alive, "yields, doesn't die")
	assert_eq(b.hp, pp.duel_yield_hp)
	assert_eq(world.duels_view()[0].state, "over")
	assert_eq(a.duel_with, -1)
	assert_false(a.is_hostile_to(b), "friends again")


func test_nobody_else_can_hurt_or_be_hurt_by_duelists() -> void:
	_start()
	world.advance(pp.duel_countdown + 0.1)
	var hp := a.hp
	_hit(c, a, 50.0)
	assert_eq(a.hp, hp, "an outsider can't hurt a duelist")
	var wolf: Enemy = world.enemies()[0]
	var whp := wolf.hp
	_hit(a, wolf, 50.0)
	assert_eq(wolf.hp, whp, "a duelist can't hurt anyone else")
	_hit(wolf, a, 50.0)
	assert_eq(a.hp, hp, "nor be hurt by them")


func test_leaving_the_boundary_warns_then_forfeits() -> void:
	_start()
	world.advance(pp.duel_countdown + 0.1)
	b.move.pos = Vector2(12, 20) + Vector2(pp.duel_radius + 1.0, 0)
	var events := world.step()
	assert_true(events.any(func(e): return e.type == "duel_out" and e.target == b.id))
	assert_almost_eq(float(world.duels_view()[0].out[b.id]), pp.duel_out_of_bounds_seconds, 0.1)
	events = world.advance(pp.duel_out_of_bounds_seconds + 0.1)
	var end: Array = events.filter(func(e): return e.type == "duel_end")
	assert_eq(end.size(), 1)
	assert_eq(end[0].reason, "fled")
	assert_eq(end[0].winner_name, "Ana")


func test_coming_back_in_time_keeps_the_duel() -> void:
	_start()
	world.advance(pp.duel_countdown + 0.1)
	b.move.pos = Vector2(12 + pp.duel_radius + 1.0, 20)
	world.advance(pp.duel_out_of_bounds_seconds * 0.5)
	b.move.pos = Vector2(13, 20)
	world.advance(pp.duel_out_of_bounds_seconds)
	assert_eq(world.duels_view()[0].state, "live")


func test_buffs_they_put_on_each_other_go_at_the_end_health_stays() -> void:
	_start()
	world.advance(pp.duel_countdown + 0.1)
	var slow := BuffDef.new()
	slow.id = &"duel_slow"
	slow.duration_seconds = 60.0
	b.buffs.apply(slow, world.now, 0.0, a.id)
	var own := BuffDef.new()
	own.id = &"own_buff"
	own.duration_seconds = 60.0
	b.buffs.apply(own, world.now, 0.0, b.id)
	_hit(a, b, 30.0)
	var hp_after := b.hp
	world.remove_hero(a.id) # a disconnect forfeits
	world.step()
	assert_false(b.buffs.has(&"duel_slow", world.now), "a's debuff on b is gone")
	assert_true(b.buffs.has(&"own_buff", world.now), "its own buff stays")
	assert_almost_eq(b.hp, hp_after, 1.0, "health isn't reset (only a tick of regen)")


func test_no_duels_in_dungeons() -> void:
	world.zone.dungeon = true
	world.submit(a.id, {"type": "duel_request", "target": b.id})
	var events := world.step()
	world.zone.dungeon = false
	assert_true(events.any(func(e): return e.type == "rejected" and e.reason == "no_duel_here"))


func test_dying_to_something_else_ends_it() -> void:
	_start()
	world.advance(pp.duel_countdown + 0.1)
	b.hp = 0.0
	b.die()
	var events := world.step()
	assert_true(events.any(func(e): return e.type == "duel_end" and e.reason == "died"))
