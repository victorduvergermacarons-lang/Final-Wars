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


func test_press_intent_shape() -> void:
	assert_eq(Intents.sanitize({"type": "timing_press", "at": 0.8}).at, 0.8)
	assert_eq(Intents.sanitize({"type": "timing_press", "at": "now"}), {})
