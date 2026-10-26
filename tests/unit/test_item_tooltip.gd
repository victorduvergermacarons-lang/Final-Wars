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


func test_shows_what_the_taught_ability_does_in_numbers() -> void:
	var punch: ItemDef = ContentDB.items[&"ember_fist_scroll"]
	var real_hero: Hero = F.hero_with([])
	var t := ItemTooltip.text(punch, real_hero, ContentDB.rules, false)
	assert_string_contains(t, "Teaches [b]Fire Punch[/b]")
	assert_string_contains(t, "Targeted · adjacent", "how it is aimed")
	assert_string_contains(t, "mana")
	assert_string_contains(t, "s cooldown")
	assert_string_contains(t, "magical damage", "the damage, in numbers for this hero")
	assert_string_contains(t, "Scales with")
	assert_string_contains(t, "Mastery from using it")


func test_a_potion_shows_its_effect_cooldown_and_stack() -> void:
	var potion: ItemDef = ContentDB.items[&"minor_health_potion"]
	var t := ItemTooltip.text(potion, F.hero_with([]), ContentDB.rules, false)
	assert_string_contains(t, "[b]Use:[/b]")
	assert_string_contains(t, "Heals [b]40% of max HP[/b]")
	assert_string_contains(t, "30s cooldown")
	assert_string_contains(t, "Shares its cooldown with other potions.")
	assert_string_contains(t, "Stacks up to 20.")


func test_which_equipment_slots_an_item_lights_up() -> void:
	assert_true(ItemSlotView.fits(sword, EquipSlot.Id.MAIN_HAND))
	assert_false(ItemSlotView.fits(sword, EquipSlot.Id.OFF_HAND))
	assert_true(ItemSlotView.fits(axe, EquipSlot.Id.MAIN_HAND), "a two-handed weapon")
	assert_true(ItemSlotView.fits(axe, EquipSlot.Id.OFF_HAND), "takes the off hand too")
	var ring := F.item(&"ring", EquipSlot.Type.ACCESSORY, {}, {})
	assert_true(ItemSlotView.fits(ring, EquipSlot.Id.ACCESSORY_1))
	assert_true(ItemSlotView.fits(ring, EquipSlot.Id.ACCESSORY_2))
	assert_false(ItemSlotView.fits(ContentDB.items[&"minor_health_potion"], EquipSlot.Id.HEAD), "not wearable")
