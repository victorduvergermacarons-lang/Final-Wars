extends GutTest
## The Milestone 2 item set (stat-only armor since Milestone 3), rarity progression,
## and the retired M2 ability mechanics.

const ContentDBScript := preload("res://autoload/content_db.gd")

var db


func before_all() -> void:
	db = ContentDBScript.new()


func after_all() -> void:
	db.free()


func _equippables() -> Array:
	return db.items.values().filter(func(i): return i.is_equippable() and i.tree == "" and not i.retired)


## Milestone 3: armor is stat-only; the old weapons and accessories are retired.
func test_armor_is_stat_only_and_old_weapons_are_retired() -> void:
	var items := _equippables()
	assert_eq(items.size(), 6)
	for item in items:
		assert_eq(item.teaches.size(), 0, "%s teaches nothing" % item.id)
	for id in [&"sword", &"staff", &"shield", &"holy_charm", &"hunting_bow", &"greataxe"]:
		assert_true(db.items[id].retired, "%s retired" % id)


func test_armor_covers_the_body() -> void:
	var slots := {}
	for item in _equippables():
		slots[item.slot] = true
	for t in [EquipSlot.Type.HEAD, EquipSlot.Type.CHEST, EquipSlot.Type.LEGS, EquipSlot.Type.FEET,
			EquipSlot.Type.HANDS]:
		assert_true(slots.has(t), "something for %s" % EquipSlot.TYPE_NAMES[t])


func test_rarer_items_are_better() -> void:
	var by_rarity := {}
	for item in _equippables():
		if not by_rarity.has(item.rarity):
			by_rarity[item.rarity] = []
		by_rarity[item.rarity].append(item)
	assert_eq(by_rarity.keys().size(), 4, "all four tiers present")
	var avg := func(list, f):
		var total := 0.0
		for i in list:
			total += f.call(i)
		return total / list.size()
	var stat_total := func(i): return i.stats.hp / 5.0 + i.stats.mana / 5.0 + i.stats.phys_atk + i.stats.mag_atk \
			+ i.stats.phys_def + i.stats.mag_def + i.stats.speed / 2.0
	assert_lt(avg.call(by_rarity[Rarity.Id.COMMON], stat_total), avg.call(by_rarity[Rarity.Id.EPIC], stat_total))


## Guards against values lost when content was generated (every mechanic in the
## design tables must be in the shipped .tres files).
func test_buffs_carry_their_mechanics() -> void:
	assert_true(db.buffs[&"frozen"].roots, "Frost Nova roots")
	assert_eq(db.buffs[&"pinned"].step_cooldown_multiplier, 2.0, "Pinning Shot slows steps x2")
	var rallied: BuffDef = db.buffs[&"rallied"]
	var stats := rallied.modifiers.map(func(m): return [m.stat, m.multiplier])
	assert_has(stats, [Stat.Id.PHYS_ATK, 1.2])
	assert_has(stats, [Stat.Id.MAG_ATK, 1.2])
	assert_eq(db.buffs[&"block"].modifiers[0].multiplier, 2.0)
	assert_eq(db.abilities[&"renew"].mana_cost, 10.0)


func test_frost_nova_roots_a_wolf_in_the_world() -> void:
	var zone: ZoneDef = db.zones[&"greenfields"]
	var world := WorldSim.new(zone, db.rules, 4)
	var hero := world.add_hero(db.heroes[&"adventurer"])
	hero.mastered[&"frost_nova"] = db.abilities[&"frost_nova"] # retired ability, still a good root test
	hero.mana = hero.stats.mana
	var wolf: Enemy = world.enemies().filter(func(e): return e.def.id == &"wolf")[0]
	hero.move.place(wolf.tile() + Vector2i(0, 1))
	world.submit(hero.id, {"type": "cast", "ability": &"frost_nova", "target": -1})
	world.step()
	assert_true(wolf.buffs.is_rooted(world.now), "wolf is rooted")
	hero.move.place(wolf.tile() + Vector2i(0, 4)) # step back out of reach
	var start := wolf.tile()
	world.advance(1.5)
	assert_eq(wolf.tile(), start, "can't follow while rooted")
	world.advance(2.0)
	assert_ne(wolf.tile(), start, "chases again once the root wears off")
