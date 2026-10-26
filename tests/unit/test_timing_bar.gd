extends GutTest
## Timing bars (TimingBarDef): a hero's Slash runs a 1 s bar; a right-click on the
## green zone casts at full power, on the yellow middle with a sure crit, elsewhere
## (or no press) at CombatRules.timing_miss_power. Moving cancels it.

const ContentDBScript := preload("res://autoload/content_db.gd")

var db
var world: World
var sim: WorldSim
var hero: Hero
var wolf: Enemy


func before_all() -> void:
	db = ContentDBScript.new()


func after_all() -> void:
	db.free()


func before_each() -> void:
	world = World.new(db.zones.values(), db.rules, 5, &"town", db.quests)
	hero = world.add_saved_hero(CharacterData.new_character("Blade", db.heroes[&"adventurer"]), db)
	sim = world.zone_of(hero.id)
	# A wolf right next to the hero, on the first free walkable neighbour.
	for d in GridModel.DIRECTIONS:
		var t: Vector2i = hero.tile() + d
		if sim.grid.in_bounds(t) and sim.grid.is_walkable(t) and not sim.is_occupied(t) \
				and absi(sim.grid.height_at(t) - sim.grid.height_at(hero.tile())) <= 1:
			wolf = sim.add_enemy(db.enemies[&"wolf"], t)
			break
	assert_not_null(wolf, "found a tile for the wolf")
	world.step()


func _slash() -> void:
	world.submit(hero.id, {"type": "cast", "ability": &"S01", "target": wolf.id})
	world.step()


## The Slash damage dealt to the wolf this tick, with crits and flanking taken out
## (so presses can be compared), or -1; and whether it was a crit.
func _press(at: float) -> Dictionary:
	world.advance(at - (world.now - float(hero.casting.start)))
	world.submit(hero.id, {"type": "timing_press", "at": at})
	for e in world.step():
		if e.type == "damage" and e.target == wolf.id and e.ability == &"S01":
			var amount: float = e.amount
			if e.crit:
				amount /= CombatMath.crit_multiplier(hero.current_stats(world.now).crit_dmg, db.rules)
			amount /= CombatMath.flank_multiplier(["", "side", "behind"].find(e.flank), db.rules)
			return {"amount": amount, "crit": e.crit}
	return {"amount": -1.0, "crit": false}


func _ready_again() -> void:
	world.advance(5.0)
	wolf.hp = wolf.stats.hp


func test_judging_slash() -> void:
	var bar: TimingBarDef = db.abilities[&"S01"].timing_bar
	assert_eq(bar.seconds, 1.0)
	assert_eq(bar.judge(0.3), TimingBarDef.Grade.MISS)
	assert_eq(bar.judge(0.4), TimingBarDef.Grade.GOOD)
	assert_eq(bar.judge(0.5), TimingBarDef.Grade.PERFECT)
	assert_eq(bar.judge(0.6), TimingBarDef.Grade.GOOD)
	assert_eq(bar.judge(0.7), TimingBarDef.Grade.MISS)


func test_slash_starts_a_bar_and_hits_on_the_press() -> void:
	_slash()
	assert_eq(hero.casting.get("kind", ""), "timing")
	assert_true(hero.cooldowns.ability_remaining(&"S01", world.now) <= 0.0, "the cooldown starts when it goes off")
	var good := _press(0.4)
	assert_gt(good.amount, 0.0, "a green press hits at once")
	assert_true(hero.casting.is_empty())
	assert_false(hero.cooldowns.ability_remaining(&"S01", world.now) <= 0.0)


func test_a_miss_hits_softer_and_yellow_always_crits() -> void:
	_slash()
	var good := _press(0.4)
	_ready_again()
	_slash()
	var miss := _press(0.1)
	assert_almost_eq(miss.amount / good.amount, db.rules.timing_miss_power, 0.08)
	_ready_again()
	_slash()
	var perfect := _press(0.5)
	assert_true(perfect.crit, "yellow: a sure critical strike")
	assert_almost_eq(perfect.amount, good.amount, good.amount * 0.08)


func test_no_press_casts_at_miss_power_when_the_bar_runs_out() -> void:
	_slash()
	var events := world.advance(1.0 + db.rules.timing_press_grace_seconds + 0.1)
	assert_true(events.any(func(e): return e.type == "timing_result" and e.grade == "miss"))
	assert_true(events.any(func(e): return e.type == "damage" and e.target == wolf.id and e.ability == &"S01"))


func test_moving_cancels_the_bar() -> void:
	_slash()
	var away: Vector2i = hero.tile() - (wolf.tile() - hero.tile())
	world.submit(hero.id, {"type": "step", "to": away})
	var events := world.step()
	if hero.tile() == away:
		assert_true(hero.casting.is_empty(), "moved: the bar is gone")
		assert_true(events.any(func(e): return e.type == "cast_cancel"))
		assert_true(hero.cooldowns.ability_remaining(&"S01", world.now) <= 0.0, "cooldown not spent")
	else:
		pass_test("the tile behind the hero is blocked here; moving is covered elsewhere")


## Healing Touch (a 2 s bar, hold 0.5–1.75) on the hero itself: the healed amount.
func _heal_with(press_at: float, release_at: float) -> float:
	hero.hp = 1.0
	hero.cooldowns = Cooldowns.new()
	var r := sim.cast(hero, db.abilities[&"W01"], hero)
	assert_eq(r, AbilityResolver.Result.OK, "Healing Touch starts (%s)" % AbilityResolver.Result.keys()[r])
	world.step()
	var events := []
	events.append_array(world.advance(press_at - (world.now - float(hero.casting.start))))
	world.submit(hero.id, {"type": "timing_press", "at": press_at})
	events.append_array(world.step())
	events.append_array(world.advance(release_at - (world.now - float(hero.casting.start))))
	world.submit(hero.id, {"type": "timing_release", "at": release_at})
	events.append_array(world.advance(1.0))
	for e in events:
		if e.type == "heal" and e.get("ability", &"") == &"W01":
			return e.amount / (1.5 if e.get("crit", false) else 1.0)
	return -1.0


func test_timing_scales_healing_too() -> void:
	sim.remove_enemy(wolf.id) # nothing bites the hero at 1 HP
	var good := _heal_with(0.5, 1.4) # let go 0.35 s early in a 1.25 s zone: 72%
	var miss := _heal_with(0.5, 0.9) # held well under half: miss power
	assert_gt(good, 0.0)
	assert_gt(miss, 0.0)
	var accuracy := TimingBarDef.hold_accuracy(db.abilities[&"W01"].timing_bar.hold_zones[0], 0.5, 1.4)
	assert_almost_eq(miss / good, db.rules.timing_miss_power / TimingBarDef.hold_power(accuracy, db.rules.timing_miss_power), 0.03)


func test_fire_punch_zones_are_at_the_end() -> void:
	var bar: TimingBarDef = db.abilities[&"F01"].timing_bar
	assert_eq(bar.seconds, 1.0)
	assert_eq(bar.judge(0.5), TimingBarDef.Grade.MISS)
	assert_eq(bar.judge(0.75), TimingBarDef.Grade.GOOD)
	assert_eq(bar.judge(0.95), TimingBarDef.Grade.PERFECT)
	assert_eq(bar.judge(1.0), TimingBarDef.Grade.PERFECT, "right up to the bar's end")


## Water Whip: a 3 s bar; hold right-click from 0.75 s to 2.75 s (the blue zone
## ends 0.25 s before the bar).
func _whip() -> void:
	sim.cast(hero, db.abilities[&"W02"], wolf)
	world.step()


## Presses at `press_at`, lets go at `release_at` (< 0: never); returns the events
## until the bar is over.
func _hold(press_at: float, release_at: float) -> Array:
	var events := []
	events.append_array(world.advance(press_at - (world.now - float(hero.casting.start))))
	world.submit(hero.id, {"type": "timing_press", "at": press_at})
	events.append_array(world.step())
	if release_at >= 0.0 and not hero.casting.is_empty():
		events.append_array(world.advance(release_at - (world.now - float(hero.casting.start))))
		world.submit(hero.id, {"type": "timing_release", "at": release_at})
	events.append_array(world.advance(3.0))
	return events


static func _result(events: Array) -> Dictionary:
	for e in events:
		if e.type == "timing_result":
			return e
	return {}


static func _whip_hit(events: Array) -> Dictionary:
	for e in events:
		if e.type == "damage" and e.ability == &"W02":
			return e
	return {}


func test_water_whip_bar() -> void:
	var bar: TimingBarDef = db.abilities[&"W02"].timing_bar
	assert_eq(bar.seconds, 3.0)
	assert_eq(bar.hold_zones, [Vector2(0.75, 2.0)] as Array[Vector2])
	assert_null(bar.hold_zone_at(0.5), "more than 0.2 s early: just a tap")
	assert_not_null(bar.hold_zone_at(0.6), "a little early starts the hold")


func test_hold_zones_end_before_their_bar() -> void:
	for ability in db.abilities.values():
		var bar: TimingBarDef = ability.timing_bar
		if bar == null:
			continue
		for z in bar.hold_zones:
			var gap: float = bar.seconds - (z.x + z.y)
			assert_between(gap, TimingBarDef.HOLD_END_GAP - 0.001, 0.3 + 0.001,
					"%s: a hold zone ends 0.2–0.3 s before the bar" % ability.id)


func test_hold_accuracy_loses_the_mistiming_in_proportion() -> void:
	var z := Vector2(0.75, 2.0)
	assert_almost_eq(TimingBarDef.hold_accuracy(z, 0.75, 2.75), 1.0, 0.001, "spot on")
	assert_almost_eq(TimingBarDef.hold_accuracy(z, 0.85, 2.75), 0.95, 0.001, "0.1 s late")
	assert_almost_eq(TimingBarDef.hold_accuracy(z, 0.65, 2.95), 0.85, 0.001, "early and held over")
	assert_almost_eq(TimingBarDef.hold_accuracy(z, 0.75, 1.75), 0.5, 0.001, "let go halfway")
	assert_eq(TimingBarDef.hold_grade(0.95), TimingBarDef.Grade.PERFECT, "95%: a crit")
	assert_eq(TimingBarDef.hold_grade(0.8), TimingBarDef.Grade.GOOD)
	assert_eq(TimingBarDef.hold_grade(0.5), TimingBarDef.Grade.MISS, "half: a miss")
	var miss: float = db.rules.timing_miss_power
	assert_almost_eq(TimingBarDef.hold_power(0.5, miss), miss, 0.001)
	assert_almost_eq(TimingBarDef.hold_power(0.725, miss), (miss + 1.0) / 2.0, 0.001, "halfway between")
	assert_almost_eq(TimingBarDef.hold_power(0.95, miss), 1.0, 0.001)
	assert_lt(TimingBarDef.hold_power(0.7, miss), TimingBarDef.hold_power(0.8, miss), "steadily better")


func test_letting_go_as_the_zone_ends_is_a_crit() -> void:
	_whip()
	assert_eq(hero.casting.get("kind", ""), "timing")
	var events := _hold(0.75, 2.75)
	assert_eq(_result(events).get("grade", ""), "perfect")
	assert_true(_whip_hit(events).get("crit", false), "a sure crit")


func test_letting_go_early_loses_power_in_proportion() -> void:
	_whip()
	var events := _hold(0.75, 2.35) # 0.4 s early: 80%
	assert_eq(_result(events).get("grade", ""), "good")
	assert_almost_eq(float(_result(events).accuracy), 0.8, 0.02)
	_whip_again()
	events = _hold(0.75, 1.5) # under half: a miss
	assert_eq(_result(events).get("grade", ""), "miss")
	assert_false(_whip_hit(events).is_empty(), "still hits, softer")


func test_still_holding_when_the_bar_ends_counts_the_overhold() -> void:
	_whip()
	var events := _hold(0.75, -1.0) # never let go: 0.25 s too long
	assert_eq(_result(events).get("grade", ""), "good")
	assert_almost_eq(float(_result(events).accuracy), 0.875, 0.02)


func test_pressing_long_before_the_blue_zone_is_a_missed_tap() -> void:
	_whip()
	var events := _hold(0.3, -1.0)
	assert_eq(_result(events).get("grade", ""), "miss")


func _whip_again() -> void:
	world.advance(5.0)
	wolf.hp = wolf.stats.hp
	_whip()


func test_bow_bars() -> void:
	var quick: TimingBarDef = db.abilities[&"B01"].timing_bar
	assert_eq(quick.seconds, 2.0)
	assert_eq(quick.hold_zones, [Vector2(0.25, 1.5)] as Array[Vector2], "hold 1.5 s, ending 0.25 s early")
	var aimed: TimingBarDef = db.abilities[&"B02"].timing_bar
	assert_eq(aimed.seconds, 4.0)
	var inputs := aimed.inputs()
	assert_eq(inputs.size(), 2, "a tap, then a hold")
	assert_eq(inputs[0].kind, "tap")
	assert_eq(inputs[0].zone, Vector2(0.2, 0.4))
	assert_eq(inputs[0].crits, [Vector2(0.35, 0.1)] as Array[Vector2])
	assert_eq(inputs[1].kind, "hold")
	assert_eq(inputs[1].zone, Vector2(1.0, 2.75))


func test_inputs_in_order() -> void:
	var bar: TimingBarDef = db.abilities[&"B02"].timing_bar
	assert_eq(bar.input_for_press(0, 0.1), 0, "early: still the tap (a miss)")
	assert_eq(bar.input_for_press(0, 0.4), 0)
	assert_eq(bar.input_for_press(0, 1.0), 1, "the tap's window is over: it's skipped")
	assert_eq(bar.input_for_press(1, 3.9), 2, "nothing left")
	var miss: float = db.rules.timing_miss_power
	var both := TimingBarDef.combine([TimingBarDef.tap_result(TimingBarDef.Grade.PERFECT, miss),
			TimingBarDef.hold_result(1.0, miss)])
	assert_eq(both.grade, TimingBarDef.Grade.PERFECT, "every input perfect: a crit")
	var one := TimingBarDef.combine([TimingBarDef.missed_input("tap", miss), TimingBarDef.hold_result(1.0, miss)])
	assert_eq(one.grade, TimingBarDef.Grade.GOOD)
	assert_almost_eq(one.power, (miss + 1.0) / 2.0, 0.001, "the average")
	assert_almost_eq(one.accuracy, 0.5, 0.001)


## Aimed Shot on the wolf: optional tap at `tap_at` (< 0: none), then the hold.
func _aimed_shot(tap_at: float) -> Array:
	assert_eq(sim.cast(hero, db.abilities[&"B02"], null, Vector2(wolf.tile())), AbilityResolver.Result.OK)
	world.step()
	var events := []
	if tap_at >= 0.0:
		events.append_array(world.advance(tap_at - (world.now - float(hero.casting.start))))
		world.submit(hero.id, {"type": "timing_press", "at": tap_at})
		events.append_array(world.step())
		assert_false(hero.casting.is_empty(), "a tap isn't the last input: the bar goes on")
	events.append_array(world.advance(1.0 - (world.now - float(hero.casting.start))))
	world.submit(hero.id, {"type": "timing_press", "at": 1.0})
	events.append_array(world.step())
	events.append_array(world.advance(3.75 - (world.now - float(hero.casting.start))))
	world.submit(hero.id, {"type": "timing_release", "at": 3.75})
	events.append_array(world.advance(1.0))
	return events


func test_aimed_shot_tap_then_hold() -> void:
	var events := _aimed_shot(0.4)
	assert_eq(_result(events).get("grade", ""), "perfect", "a yellow tap and a spot-on hold")
	var hit := {}
	for e in events:
		if e.type == "damage" and e.ability == &"B02":
			hit = e
	assert_true(hit.get("crit", false), "a sure crit")


func test_skipping_the_tap_halves_the_score() -> void:
	var events := _aimed_shot(-1.0)
	var r := _result(events)
	assert_eq(r.get("grade", ""), "good")
	assert_almost_eq(float(r.accuracy), 0.5, 0.01, "tap missed (0%), hold perfect (100%)")


func test_aimed_bars_fire_where_the_last_input_points() -> void:
	# Fire Dart (0.8 s, tap 0.5–0.75), started aimed away from the wolf…
	var away := Vector2(hero.tile() - (wolf.tile() - hero.tile()) * 3)
	assert_eq(sim.cast(hero, db.abilities[&"F03"], null, away), AbilityResolver.Result.OK)
	world.step()
	world.advance(0.55 - (world.now - float(hero.casting.start)))
	# …and the press points at it: the dart flies at the wolf.
	world.submit(hero.id, {"type": "timing_press", "at": 0.55, "aim": Vector2(wolf.tile())})
	var events := world.advance(1.0)
	assert_true(events.any(func(e): return e.type == "damage" and e.target == wolf.id and e.ability == &"F03"))


func test_ground_bars_start_beyond_range_and_land_at_its_edge() -> void:
	var far := Vector2(hero.tile()) + Vector2(20, 0)
	assert_eq(sim.cast(hero, db.abilities[&"F07"], null, far), AbilityResolver.Result.OK, "Fireball starts anyway")
	var aim: Vector2 = hero.casting.aim
	assert_lte(hero.range_to(Vector2i(aim.round())), db.abilities[&"F07"].max_range, "pulled back into range")
	assert_gt(aim.x, float(hero.tile().x), "toward where the cursor was")


func test_press_intent_shape() -> void:
	assert_eq(Intents.sanitize({"type": "timing_press", "at": 0.8}).at, 0.8)
	assert_eq(Intents.sanitize({"type": "timing_press", "at": "now"}), {})
	assert_eq(Intents.sanitize({"type": "timing_release", "at": 1, "aim": Vector2(3, 4)}).aim, Vector2(3, 4), "an aimed input carries the cursor")
	assert_eq(Intents.sanitize({"type": "timing_press", "at": 1, "aim": "here"}), {})
