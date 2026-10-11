extends GutTest

var rules: CombatRules


func before_each() -> void:
	rules = CombatRules.new()


func test_hit_chance_base_and_per_point() -> void:
	assert_almost_eq(CombatMath.hit_chance(0, 0, rules), 0.95, 0.0001)
	assert_almost_eq(CombatMath.hit_chance(10, 20, rules), 0.85, 0.0001)


func test_hit_chance_is_clamped() -> void:
	assert_almost_eq(CombatMath.hit_chance(50, 0, rules), 1.0, 0.0001)
	assert_almost_eq(CombatMath.hit_chance(0, 500, rules), 0.5, 0.0001)


func test_crit_chance_and_multiplier() -> void:
	assert_almost_eq(CombatMath.crit_chance(25), 0.25, 0.0001)
	assert_eq(CombatMath.crit_chance(-5), 0.0)
	assert_eq(CombatMath.crit_chance(150), 1.0)
	assert_almost_eq(CombatMath.crit_multiplier(0, rules), 1.5, 0.0001, "base +50%")
	assert_almost_eq(CombatMath.crit_multiplier(30, rules), 1.8, 0.0001)


func test_mitigation_curve() -> void:
	assert_eq(CombatMath.mitigation(0, 100), 0.0)
	assert_eq(CombatMath.mitigation(-10, 100), 0.0)
	assert_almost_eq(CombatMath.mitigation(100, 100), 0.5, 0.0001)
	assert_almost_eq(CombatMath.mitigation(300, 100), 0.75, 0.0001)


func test_defense_for_picks_matching_stat() -> void:
	var s := StatBlock.make({Stat.Id.PHYS_DEF: 40, Stat.Id.MAG_DEF: 7})
	rules.magical_defense_k = 50
	assert_eq(CombatMath.defense_for(AbilityEffect.DamageType.PHYSICAL, s, rules), Vector2(40, 100))
	assert_eq(CombatMath.defense_for(AbilityEffect.DamageType.MAGICAL, s, rules), Vector2(7, 50))


func test_high_ground_only_helps_ranged_from_above() -> void:
	assert_almost_eq(CombatMath.high_ground_multiplier(2, true, rules), 1.2, 0.0001)
	assert_eq(CombatMath.high_ground_multiplier(2, false, rules), 1.0, "melee")
	assert_eq(CombatMath.high_ground_multiplier(-3, true, rules), 1.0, "no penalty from below")


func test_final_damage_rounds_and_has_a_floor() -> void:
	assert_eq(CombatMath.final_damage(30, 100, 100, rules), 15.0)
	assert_eq(CombatMath.final_damage(10.6, 0, 100, rules), 11.0)
	assert_eq(CombatMath.final_damage(0.2, 1000, 100, rules), 1.0)
