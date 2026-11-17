extends GutTest
## The 2026-11-17 rebalance: ranged abilities reach 2 tiles further (dashes don't);
## Water's heals scale with 0.45 Magic Attack and 0.55 Physical Defense; Air hits
## with Physical Attack (its control and defense abilities 0.6 Physical Attack and
## 0.4 Magic Defense); the sheet's Scales With carries those coefficients.


func _a(id: String) -> AbilityDef:
	return ContentDB.abilities[StringName(id)]


func _hero(stats: Dictionary) -> Hero:
	var hd := HeroDef.new()
	hd.base_stats = StatBlock.make(stats)
	return Hero.from_def(1, hd)


func test_ranged_abilities_reach_two_tiles_further() -> void:
	var want := {"W01": 4, "W02": 5, "W05": 6, "F03": 6, "F07": 7, "B01": 7, "B02": 9, "E01": 6, "A02": 5, "W09": 6}
	for id in want:
		assert_eq(_a(id).max_range, want[id], id)
	assert_eq(_a("W01").hitbox.reach, 4.0, "the hitbox too")
	assert_eq(_a("F03").hitbox.reach, 6.5)
	assert_eq(_a("F05").max_range, 3, "a dash isn't a ranged attack")
	assert_eq(_a("S04").max_range, 3)
	assert_eq(_a("S01").hitbox.reach, 1.4, "melee stays melee")


func test_water_heals_lean_on_magic_attack_and_physical_defense() -> void:
	var rules: CombatRules = ContentDB.rules
	var heal := _a("W01")
	var effect: AbilityEffect = heal.effects[0]
	var base := AbilityPower.amount(_hero({}), heal, effect, 0.0, rules)
	var ma := AbilityPower.amount(_hero({Stat.Id.MAG_ATK: 100}), heal, effect, 0.0, rules) - base
	var pd := AbilityPower.amount(_hero({Stat.Id.PHYS_DEF: 100}), heal, effect, 0.0, rules) - base
	assert_almost_eq(ma, 45.0 * effect.power, 0.01, "0.45 per Magic Attack")
	assert_almost_eq(pd, 55.0 * effect.power, 0.01, "0.55 per Physical Defense")
	for id in ["W05", "W10", "W17"]:
		assert_eq(_a(id).sheet.scales_with_text, "Water Mastery, 0.45 Magic Atk, 0.55 Phys Def", id)
	assert_eq(_a("W02").sheet.scales_with_text, "Water Mastery, Magic Atk", "damage stays on Magic Attack")


func test_air_hits_with_physical_attack() -> void:
	var rules: CombatRules = ContentDB.rules
	var palm := _a("A01")
	var effect: AbilityEffect = palm.effects.filter(func(e): return e.kind == AbilityEffect.Kind.DAMAGE)[0]
	var base := AbilityPower.amount(_hero({}), palm, effect, 0.0, rules)
	assert_gt(AbilityPower.amount(_hero({Stat.Id.PHYS_ATK: 100}), palm, effect, 0.0, rules), base)
	assert_eq(AbilityPower.amount(_hero({Stat.Id.MAG_ATK: 100}), palm, effect, 0.0, rules), base, "not Magic Attack")
	assert_eq(_a("A02").sheet.scales_with_text, "Air Mastery, 0.6 Phys Atk, 0.4 Magic Def", "Gust: control")
	for id in ContentDB.abilities:
		var a: AbilityDef = ContentDB.abilities[id]
		if a.is_tree_ability() and a.tree == "Air":
			assert_false("Magic Atk" in str(a.sheet.scales_with_text), "%s: no Magic Attack" % id)


func test_the_importer_reads_coefficients() -> void:
	var errors: PackedStringArray = []
	var out := AbilityTreeImporter._scales_with("Water Mastery, 0.45 Magic Atk, 0.55 Phys Def", {"Water": true}, "W01", errors)
	assert_eq(errors, PackedStringArray())
	assert_eq(out, [{"mastery": "Water"}, {"stat": "mag_atk", "coef": 0.45}, {"stat": "phys_def", "coef": 0.55}])
	AbilityTreeImporter._scales_with("Water Mastery, -1 Magic Atk", {"Water": true}, "X", errors)
	assert_eq(errors.size(), 1, "a coefficient must be above 0")
