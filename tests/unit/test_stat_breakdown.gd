extends GutTest

const F := preload("res://tests/unit/progression_fixtures.gd")


func test_rows_split_base_growth_gear_and_buffs() -> void:
	var sword := F.item(&"sword", EquipSlot.Type.MAIN_HAND, {Stat.Id.PHYS_ATK: 12}, {Stat.Id.PHYS_ATK: 4})
	var hero := F.hero_with([sword])
	hero.base_stats.phys_atk = 10
	hero.growth.phys_atk = 6
	hero.refresh_stats()
	var buff := BuffDef.new()
	buff.id = &"rage"
	buff.duration_seconds = 10
	buff.modifiers = [StatModifier.make(Stat.Id.PHYS_ATK, 1.5)]
	hero.buffs.apply(buff, 0.0)
	var row: Dictionary = StatBreakdown.rows(hero, 1.0)[Stat.Id.PHYS_ATK]
	assert_eq(row.base, 10.0)
	assert_eq(row.growth, 6.0)
	assert_eq(row.gear, 12.0)
	assert_eq(row.total, 42.0)
	assert_eq(row.buffs, 14.0, "the buff's share")


func test_abilities_mastered_and_in_progress() -> void:
	var strike := F.ability(&"strike", 20)
	var fire := F.ability(&"fireball", 20)
	var heal := F.ability(&"heal", 20)
	var sword := F.item(&"sword", EquipSlot.Type.MAIN_HAND, {}, {}, [strike])
	var staff := F.item(&"staff", EquipSlot.Type.MAIN_HAND, {}, {}, [fire])
	var charm := F.item(&"charm", EquipSlot.Type.ACCESSORY, {}, {}, [heal])
	var hero := F.hero_with([sword])
	hero.bag.add(staff)
	hero.bag.add(charm)
	hero.ap[&"fireball"] = 10
	hero.mastered[&"heal"] = heal
	var ab := StatBreakdown.abilities(hero)
	assert_eq(ab.mastered, [heal])
	assert_eq(ab.in_progress.size(), 2)
	assert_eq(ab.in_progress[0].ability, strike)
	assert_true(ab.in_progress[0].earning)
	assert_eq(ab.in_progress[1].ability, fire)
	assert_false(ab.in_progress[1].earning, "staff is in the bag")
	assert_eq(ab.in_progress[1].ap, 10)
