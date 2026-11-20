extends GutTest
## Binding: Bind on Pickup (scrolls, boss key items; tradeable to the fight's members
## for a while), Bind on Equip (gear, free until worn), Unbound (materials,
## consumables, gold). Shown in tooltips.

const LEGACY_HERO := preload("res://tests/fixtures/legacy_adventurer.tres")


func _helm() -> ItemDef:
	return ContentDB.items[&"iron_helm"]


func test_kinds() -> void:
	assert_eq(Binding.kind_of(ContentDB.items[&"pebble_scroll"]), Binding.Kind.BIND_ON_PICKUP)
	assert_eq(Binding.kind_of(_helm()), Binding.Kind.BIND_ON_EQUIP)
	assert_eq(Binding.kind_of(ContentDB.items[&"wolf_pelt"]), Binding.Kind.UNBOUND)
	assert_eq(Binding.kind_of(ContentDB.items[&"minor_health_potion"]), Binding.Kind.UNBOUND)


func test_scrolls_bind_in_the_bag_and_gear_binds_when_worn() -> void:
	var hero := Hero.new(1)
	hero.bag.add(ContentDB.items[&"pebble_scroll"])
	assert_true(Binding.is_bound(hero.bag.bind_at(0)), "a scroll is bound once it's yours")
	hero.bag.add(_helm())
	assert_false(Binding.is_bound(hero.bag.bind_at(1)), "gear is free in the bag")
	assert_eq(hero.equip_from_bag(1), "")
	assert_eq(hero.unequip_to_bag(EquipSlot.Id.HEAD), "")
	var at := hero.bag.index_of(_helm())
	assert_true(Binding.is_bound(hero.bag.bind_at(at)), "worn once: bound")


func test_bound_and_free_stacks_never_merge() -> void:
	var bag := Bag.new()
	var pelt: ItemDef = ContentDB.items[&"wolf_pelt"]
	bag.add(pelt, 2)
	bag.add(pelt, 2, {"bound": true})
	assert_eq(bag.slots.filter(func(s): return s != null).size(), 2)
	bag.move(1, 0) # swaps instead of merging
	assert_eq(bag.slots.filter(func(s): return s != null).size(), 2)


func test_a_bop_window_lets_the_fight_trade_for_a_while() -> void:
	var b := Binding.on_acquire(ContentDB.items[&"pebble_scroll"], ["Ana", "Bo"], 1200.0)
	assert_true(Binding.can_trade(b, "Bo", 100.0))
	assert_false(Binding.can_trade(b, "Cy", 100.0), "not in that fight")
	assert_false(Binding.can_trade(b, "Bo", 1200.0), "the window has closed")
	assert_true(Binding.can_trade({}, "Cy", 100.0), "free items trade to anyone")
	assert_false(Binding.can_trade({"bound": true}, "Bo", 0.0), "bound without a window")


func test_looted_scrolls_get_the_window_and_saves_drop_it() -> void:
	var world := WorldSim.new(ContentDB.zones[&"greenfields"], ContentDB.rules, 3)
	var a := world.add_hero(LEGACY_HERO)
	a.display_name = "Ana"
	a.move.place(Vector2i(12, 20))
	var scroll: ItemDef = ContentDB.items[&"pebble_scroll"]
	var id := world.drops.add(a.id, scroll, 1, a.move.pos, 999.0, &"test", ["Ana", "Bo"])
	world.submit(a.id, {"type": "pick_up", "drop": id})
	world.step()
	var at := a.bag.index_of(scroll)
	var bind := a.bag.bind_at(at)
	assert_almost_eq(Binding.trade_seconds_left(bind, world.now), ContentDB.rules.party_play.bop_trade_seconds, 0.2)
	assert_eq(Array(bind.fight), ["Ana", "Bo"])
	var back := CharacterData.restore(2, CharacterData.capture(a), ContentDB)
	assert_eq(back.bag.bind_at(back.bag.index_of(scroll)), {"bound": true}, "saved: bound, no window")


func test_tooltips_show_the_binding() -> void:
	var rules := ContentDB.rules
	var t := ItemTooltip.text(_helm(), null, rules, false, 0.0)
	assert_string_contains(t, "Bind on Equip")
	t = ItemTooltip.text(_helm(), null, rules, true, 0.0)
	assert_string_contains(t, "Soulbound", "worn")
	t = ItemTooltip.text(ContentDB.items[&"wolf_pelt"], null, rules, false, 0.0)
	assert_string_contains(t, "Not bound")
	t = ItemTooltip.text(ContentDB.items[&"pebble_scroll"], null, rules, false, 100.0,
			{"bound": true, "until": 200.0, "fight": ["Ana", "Bo"]})
	assert_string_contains(t, "Soulbound")
	assert_string_contains(t, "Tradeable to Ana, Bo for 1:40")
