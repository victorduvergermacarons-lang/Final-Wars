extends GutTest

const GCD := 1.0

var cd: Cooldowns


func _ability(id: StringName, cooldown: float, on_gcd: bool = true) -> AbilityDef:
	var a := AbilityDef.new()
	a.id = id
	a.cooldown_seconds = cooldown
	a.on_gcd = on_gcd
	return a


func before_each() -> void:
	cd = Cooldowns.new()


func test_everything_ready_initially() -> void:
	assert_true(cd.can_use(_ability(&"fireball", 8.0), 0.0))
	assert_true(cd.can_step(0.0))
	assert_eq(cd.gcd_remaining(0.0), 0.0)


func test_ability_cooldown_blocks_until_expired() -> void:
	var fireball := _ability(&"fireball", 8.0)
	cd.trigger(fireball, 10.0, GCD)
	assert_false(cd.can_use(fireball, 17.9))
	assert_almost_eq(cd.ability_remaining(&"fireball", 14.0), 4.0, 0.0001)
	assert_true(cd.can_use(fireball, 18.0))


func test_gcd_blocks_other_gcd_abilities() -> void:
	cd.trigger(_ability(&"strike", 0.0), 5.0, GCD)
	var heal := _ability(&"heal", 0.0)
	assert_false(cd.can_use(heal, 5.5), "inside GCD")
	assert_true(cd.can_use(heal, 6.0), "GCD over")


func test_off_gcd_ability_ignores_and_does_not_trigger_gcd() -> void:
	var kick := _ability(&"kick", 20.0, false)
	cd.trigger(_ability(&"strike", 0.0), 0.0, GCD)
	assert_true(cd.can_use(kick, 0.1), "usable during GCD")
	cd.trigger(kick, 2.0, GCD)
	assert_eq(cd.gcd_remaining(2.0), 0.0, "did not start a GCD")
	assert_false(cd.can_use(kick, 21.0))


func test_ability_shorter_than_gcd_waits_for_gcd() -> void:
	var jab := _ability(&"jab", 0.5)
	cd.trigger(jab, 0.0, GCD)
	assert_false(cd.can_use(jab, 0.7), "own cd done, GCD still running")
	assert_true(cd.can_use(jab, 1.0))


func test_cooldowns_are_per_ability() -> void:
	cd.trigger(_ability(&"fireball", 8.0), 0.0, GCD)
	assert_true(cd.can_use(_ability(&"strike", 0.0), 1.0))


func test_fractions_for_ui_sweeps() -> void:
	cd.trigger(_ability(&"fireball", 8.0), 0.0, GCD)
	assert_almost_eq(cd.ability_fraction(&"fireball", 2.0), 0.75, 0.0001)
	assert_almost_eq(cd.gcd_fraction(0.25), 0.75, 0.0001)
	assert_eq(cd.ability_fraction(&"fireball", 100.0), 0.0)
	assert_eq(cd.ability_fraction(&"unknown", 0.0), 0.0)


func test_step_cooldown() -> void:
	cd.trigger_step(3.0, 0.4)
	assert_false(cd.can_step(3.2))
	assert_true(cd.can_step(3.4))


func test_accumulated_tick_time_reaches_ready() -> void:
	var a := _ability(&"a", 1.0)
	cd.trigger(a, 0.0, GCD)
	var now := 0.0
	for i in 20:
		now += 0.05
	assert_true(cd.can_use(a, now), "20 × 0.05s ticks = 1s despite float drift")


func test_dict_round_trip() -> void:
	cd.trigger(_ability(&"fireball", 8.0), 1.0, GCD)
	cd.trigger_step(1.0, 0.5)
	var copy := Cooldowns.from_dict(cd.to_dict())
	assert_almost_eq(copy.ability_remaining(&"fireball", 3.0), 6.0, 0.0001)
	assert_almost_eq(copy.gcd_remaining(1.5), 0.5, 0.0001)
	assert_almost_eq(copy.step_remaining(1.25), 0.25, 0.0001)
