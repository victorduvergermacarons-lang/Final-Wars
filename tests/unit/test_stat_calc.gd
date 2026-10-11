extends GutTest

var rules: CombatRules


func before_each() -> void:
	rules = CombatRules.new()
	rules.combat_step_base_seconds = 0.6
	rules.combat_step_min_seconds = 0.3
	rules.speed_half_point = 100.0


func _item(stats: Dictionary) -> ItemDef:
	var item := ItemDef.new()
	item.id = &"test_item"
	item.stats = StatBlock.make(stats)
	return item


func test_total_adds_base_growth_and_equipped_items() -> void:
	var base := StatBlock.make({Stat.Id.HP: 100, Stat.Id.JUMP: 2})
	var growth := StatBlock.make({Stat.Id.HP: 15})
	var equipped: Array[ItemDef] = [
		_item({Stat.Id.PHYS_ATK: 10}),
		_item({Stat.Id.HP: 5, Stat.Id.PHYS_DEF: 8}),
		null,
	]
	var t := StatCalc.total(base, growth, equipped)
	assert_eq(t.hp, 120.0)
	assert_eq(t.phys_atk, 10.0)
	assert_eq(t.phys_def, 8.0)
	assert_eq(t.jump, 2.0)
	assert_eq(base.hp, 100.0, "inputs unchanged")


func test_scaled_amount_matches_brief_example() -> void:
	# damage = base + 1.2 × Magic Attack
	var stats := StatBlock.make({Stat.Id.MAG_ATK: 50})
	var scaling: Array[AbilityScaling] = [AbilityScaling.make(Stat.Id.MAG_ATK, 1.2)]
	assert_almost_eq(StatCalc.scaled_amount(20.0, scaling, stats), 80.0, 0.0001)


func test_scaled_amount_sums_terms_and_never_goes_negative() -> void:
	var stats := StatBlock.make({Stat.Id.PHYS_ATK: 10, Stat.Id.MAG_ATK: 20})
	var scaling: Array[AbilityScaling] = [
		AbilityScaling.make(Stat.Id.PHYS_ATK, 1.0),
		AbilityScaling.make(Stat.Id.MAG_ATK, 0.5),
	]
	assert_almost_eq(StatCalc.scaled_amount(5.0, scaling, stats), 25.0, 0.0001)
	var negative: Array[AbilityScaling] = [AbilityScaling.make(Stat.Id.PHYS_ATK, -10.0)]
	assert_eq(StatCalc.scaled_amount(5.0, negative, stats), 0.0)


func test_step_cooldown_is_base_at_zero_speed() -> void:
	assert_almost_eq(StatCalc.combat_step_cooldown(0.0, rules), 0.6, 0.0001)


func test_step_cooldown_halves_at_half_point_then_floors() -> void:
	assert_almost_eq(StatCalc.combat_step_cooldown(50.0, rules), 0.4, 0.0001)
	assert_almost_eq(StatCalc.combat_step_cooldown(100.0, rules), 0.3, 0.0001)
	assert_almost_eq(StatCalc.combat_step_cooldown(1000.0, rules), 0.3, 0.0001)


func test_step_cooldown_ignores_negative_speed() -> void:
	assert_almost_eq(StatCalc.combat_step_cooldown(-50.0, rules), 0.6, 0.0001)


func test_jump_levels_floors_and_clamps() -> void:
	assert_eq(StatCalc.jump_levels(StatBlock.make({Stat.Id.JUMP: 2.9})), 2)
	assert_eq(StatCalc.jump_levels(StatBlock.make({Stat.Id.JUMP: -1})), 0)

