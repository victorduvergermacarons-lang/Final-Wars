extends GutTest


func _valid_ability() -> AbilityDef:
	var a := AbilityDef.new()
	a.id = &"strike"
	a.effects = [AbilityEffect.new()]
	return a


func test_valid_ability_has_no_errors() -> void:
	assert_eq(_valid_ability().validate().size(), 0)


func test_ability_validation_catches_problems() -> void:
	var a := _valid_ability()
	a.id = &""
	a.min_range = 3
	a.max_range = 1
	a.effects = []
	assert_eq(a.validate().size(), 3)


func test_item_validation_includes_ability_errors() -> void:
	var item := ItemDef.new()
	item.id = &"sword"
	var bad := _valid_ability()
	bad.cooldown_seconds = -1.0
	item.teaches = [bad]
	assert_eq(item.validate().size(), 1)


func test_new_items_get_distinct_stat_blocks() -> void:
	var a := ItemDef.new()
	var b := ItemDef.new()
	a.stats.hp = 10
	assert_eq(b.stats.hp, 0.0)


func test_default_rules_resource_loads() -> void:
	var rules := load("res://content/rules/default_rules.tres") as CombatRules
	assert_not_null(rules)
	assert_eq(rules.gcd_seconds, 1.0)
