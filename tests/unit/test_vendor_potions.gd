extends GutTest
## Vendor buy/sell and potions.

const ContentDBScript := preload("res://autoload/content_db.gd")

var db
var world: World
var town: WorldSim
var hero: Hero
var hilda: Npc
var hp_potion: ItemDef
var mp_potion: ItemDef


func before_all() -> void:
	db = ContentDBScript.new()


func after_all() -> void:
	db.free()


func before_each() -> void:
	world = World.new(db.zones.values(), db.rules, 1, &"town")
	hero = world.add_saved_hero(CharacterData.new_character("Zed", db.heroes[&"adventurer"]), db)
	town = world.zone(&"town")
	for n in town.npcs():
		if n.def.id == &"hilda":
			hilda = n
	hero.move.place(hilda.tile() + Vector2i(0, 2))
	hp_potion = db.items[&"minor_health_potion"]
	mp_potion = db.items[&"minor_mana_potion"]


func _do(intent: Dictionary) -> Array[Dictionary]:
	world.submit(hero.id, intent)
	return world.step()


func _rejection(events: Array) -> String:
	for e in events:
		if e.type == "rejected":
			return e.reason
	return ""


func test_hilda_sells_potions_and_common_gear() -> void:
	var ids := hilda.def.sells.map(func(i): return i.id)
	for id in [&"minor_health_potion", &"minor_mana_potion", &"iron_helm", &"hunting_bow", &"swift_boots"]:
		assert_has(ids, id)
	for item in hilda.def.sells:
		assert_eq(item.rarity, Rarity.Id.COMMON, "only Common goods")


func test_buying_costs_gold_and_needs_enough() -> void:
	hero.gold = 50
	_do({"type": "buy", "npc": hilda.id, "item": &"minor_health_potion", "count": 2})
	assert_eq(hero.gold, 10)
	assert_eq(hero.bag.count_of(hp_potion), 2)
	assert_eq(_rejection(_do({"type": "buy", "npc": hilda.id, "item": &"minor_health_potion", "count": 1})), "not_enough_gold")


func test_buying_checks_distance_stock_and_bag_room() -> void:
	hero.gold = 1000
	assert_eq(_rejection(_do({"type": "buy", "npc": hilda.id, "item": &"sword", "count": 1})), "not_sold_here")
	var junk := ItemDef.new()
	junk.id = &"junk"
	hero.bag.add(junk, hero.bag.free_slots())
	assert_eq(_rejection(_do({"type": "buy", "npc": hilda.id, "item": &"minor_mana_potion", "count": 1})), "bag_full")
	hero.move.place(Vector2i(16, 16))
	assert_eq(_rejection(_do({"type": "buy", "npc": hilda.id, "item": &"minor_mana_potion", "count": 1})), "too_far")
	assert_eq(hero.gold, 1000, "nothing charged")


func test_selling_pays_a_quarter_of_the_price() -> void:
	var pelt: ItemDef = db.items[&"wolf_pelt"]
	hero.bag.add(pelt, 5)
	var index := hero.bag.index_of(pelt)
	_do({"type": "sell", "npc": hilda.id, "bag_index": index, "count": 5})
	assert_eq(hero.gold, 10, "5 × floor(8 × 25%)")
	assert_eq(hero.bag.count_of(pelt), 0)


func test_worthless_items_cant_be_sold() -> void:
	var quest_item := ItemDef.new()
	quest_item.id = &"letter"
	quest_item.price = 0
	hero.bag.add(quest_item)
	assert_eq(_rejection(_do({"type": "sell", "npc": hilda.id, "bag_index": hero.bag.index_of(quest_item), "count": 1})), "cant_sell")


func test_health_potion_restores_40_percent_and_is_used_up() -> void:
	hero.bag.add(hp_potion, 2)
	hero.hp = 10
	_do({"type": "use_item", "bag_index": hero.bag.index_of(hp_potion)})
	assert_almost_eq(hero.hp, 10 + roundf(hero.stats.hp * 0.4), 0.5, "plus a tick of regen")
	assert_eq(hero.bag.count_of(hp_potion), 1)


func test_potions_share_one_30s_cooldown_and_skip_the_gcd() -> void:
	hero.bag.add(hp_potion)
	hero.bag.add(mp_potion)
	hero.hp = 10
	hero.mana = 0
	_do({"type": "use_item", "bag_index": hero.bag.index_of(hp_potion)})
	assert_eq(hero.cooldowns.gcd_remaining(world.now), 0.0, "no GCD")
	assert_eq(_rejection(_do({"type": "use_item", "bag_index": hero.bag.index_of(mp_potion)})), "on_cooldown",
			"mana potion shares the cooldown")
	assert_eq(hero.bag.count_of(mp_potion), 1, "not used up when refused")
	world.advance(30.0)
	hero.mana = 0 # regen refilled it while waiting
	_do({"type": "use_item", "bag_index": hero.bag.index_of(mp_potion)})
	assert_almost_eq(hero.mana, roundf(hero.stats.mana * 0.4), 1.0)


func test_potions_work_in_combat() -> void:
	hero.bag.add(hp_potion)
	hero.hp = 10
	hero.combat_until = world.now + 100
	_do({"type": "use_item", "bag_index": hero.bag.index_of(hp_potion)})
	assert_gt(hero.hp, 10.0)


func test_non_consumables_cant_be_used() -> void:
	assert_eq(_rejection(_do({"type": "use_item", "bag_index": hero.bag.index_of(db.items[&"staff"])})), "not_usable")


func test_action_bar_holds_potions() -> void:
	var bar := ActionBarModel.new()
	bar.assign(4, ActionBarModel.item_entry(&"minor_health_potion"))
	assert_true(ActionBarModel.is_item_slot(bar.slots[4]))
	assert_eq(ActionBarModel.item_id_of(bar.slots[4]), &"minor_health_potion")
	assert_false(ActionBarModel.is_item_slot(&"strike"))
