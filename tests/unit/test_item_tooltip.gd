extends GutTest

const F := preload("res://tests/unit/progression_fixtures.gd")

var rules: CombatRules
var hero: Hero
var sword: ItemDef
var axe: ItemDef


func before_each() -> void:
	rules = CombatRules.new()
	var strike := F.ability(&"strike", 20)
	strike.display_name = "Strike"
	sword = F.item(&"sword", EquipSlot.Type.MAIN_HAND, {Stat.Id.PHYS_ATK: 12, Stat.Id.ACCURACY: 5},
			{Stat.Id.PHYS_ATK: 4}, [strike])
	sword.display_name = "Sword"
	sword.price = 40
	axe = F.item(&"axe", EquipSlot.Type.TWO_HAND, {Stat.Id.PHYS_ATK: 20}, {})
	axe.display_name = "Greataxe"
	axe.rarity = Rarity.Id.UNCOMMON
	hero = F.hero_with([sword])


func test_shows_name_in_rarity_color_stats_growth_ability_and_price() -> void:
	var t := ItemTooltip.text(sword, hero, rules, true)
	assert_string_contains(t, Rarity.color(Rarity.Id.COMMON).to_html(false))
	assert_string_contains(t, "Sword")
	assert_string_contains(t, "+12 Physical Attack")
	assert_string_contains(t, "Per level while worn: +2 Physical Attack", "growth × 50%")
	assert_string_contains(t, "Teaches [b]Strike[/b] — AP 0 / 20")
	assert_string_contains(t, "Sells for 10 gold")
	assert_false(t.contains("If equipped"), "no comparison for worn items")


func test_ap_progress_and_mastery() -> void:
	hero.ap[&"strike"] = 10
	assert_string_contains(ItemTooltip.text(sword, hero, rules, true), "AP 10 / 20")
	hero.mastered[&"strike"] = sword.teaches[0]
	assert_string_contains(ItemTooltip.text(sword, hero, rules, true), "mastered")


func test_comparison_against_what_it_would_replace() -> void:
	var lines := ItemTooltip.compare(axe, hero)
	assert_eq(lines.size(), 2)
	assert_string_contains(lines[0], ItemTooltip.GREEN)
	assert_string_contains(lines[0], "+8 Physical Attack")
	assert_string_contains(lines[1], ItemTooltip.RED)
	assert_string_contains(lines[1], "-5 Accuracy")
	assert_string_contains(ItemTooltip.text(axe, hero, rules, false), "If equipped:")
	assert_string_contains(ItemTooltip.text(axe, hero, rules, false), Rarity.color(Rarity.Id.UNCOMMON).to_html(false))
