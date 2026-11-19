extends GutTest
## Player-to-player trading: request, escrow, offer and unlock, the contract, the
## one-go swap, and every way a trade is cancelled (everything goes back).

const LEGACY_HERO := preload("res://tests/fixtures/legacy_adventurer.tres")

var world: WorldSim
var a: Hero
var b: Hero
var helm: ItemDef
var pelt: ItemDef


func before_each() -> void:
	world = WorldSim.new(ContentDB.zones[&"greenfields"], ContentDB.rules, 5)
	for e in world.enemies():
		e.move.place(Vector2i(29, 29))
	a = world.add_hero(LEGACY_HERO)
	b = world.add_hero(LEGACY_HERO)
	a.display_name = "Ana"
	b.display_name = "Bo"
	a.move.place(Vector2i(10, 20))
	b.move.place(Vector2i(12, 20))
	helm = ContentDB.items[&"iron_helm"]
	pelt = ContentDB.items[&"wolf_pelt"]
	a.bag.add(helm)
	b.bag.add(pelt, 3)
	a.gold = 50
	b.gold = 10


func _do(h: Hero, intent: Dictionary) -> Array[Dictionary]:
	world.submit(h.id, intent)
	return world.step()


func _open() -> Dictionary:
	_do(a, {"type": "trade_request", "target": b.id})
	var r: Dictionary = world.social_view(b.id).requests[0]
	assert_eq(r.from_name, "Ana")
	_do(b, {"type": "request_answer", "request": r.id, "accept": true})
	return world.social.trade_of(a.id)


func test_a_full_trade_swaps_everything_at_once() -> void:
	var t := _open()
	assert_false(t.is_empty())
	_do(a, {"type": "trade_add", "index": a.bag.index_of(helm), "count": 1})
	assert_eq(a.bag.count_of(helm), 0, "in escrow: out of the bag")
	_do(a, {"type": "trade_gold", "amount": 20})
	assert_eq(a.gold, 30, "gold in escrow too")
	_do(b, {"type": "trade_add", "index": b.bag.index_of(pelt), "count": 3})
	_do(a, {"type": "trade_offer"})
	assert_eq(world.social_view(a.id).trade.stage, "edit", "one side offered")
	_do(b, {"type": "trade_offer"})
	var view: Dictionary = world.social_view(b.id).trade
	assert_eq(view.stage, "contract")
	assert_string_contains(TradeWindow.contract_text(view), "You give Ana:[/b] Wolf Pelt x3")
	assert_string_contains(TradeWindow.contract_text(view), "You get from Ana:[/b] Iron Helm, 20 gold")
	_do(a, {"type": "trade_accept"})
	assert_eq(b.bag.count_of(helm), 0, "nothing moves until both accept")
	var events := _do(b, {"type": "trade_accept"})
	assert_true(events.any(func(e): return e.type == "trade_done"))
	assert_eq(b.bag.count_of(helm), 1)
	assert_eq(a.bag.count_of(pelt), 3)
	assert_eq(a.gold, 30)
	assert_eq(b.gold, 30)
	assert_true(world.social.trade_of(a.id).is_empty())


func test_a_change_after_offering_unlocks_both() -> void:
	_open()
	_do(a, {"type": "trade_offer"})
	_do(b, {"type": "trade_offer"})
	assert_eq(world.social_view(a.id).trade.stage, "contract")
	_do(b, {"type": "trade_gold", "amount": 5})
	var v: Dictionary = world.social_view(a.id).trade
	assert_eq(v.stage, "edit")
	assert_false(v.mine.locked or v.theirs.locked, "both unlocked")


func test_cancelling_returns_everything() -> void:
	for how in ["decline", "too_far", "in_combat", "left"]:
		before_each()
		_open()
		_do(a, {"type": "trade_add", "index": a.bag.index_of(helm), "count": 1})
		_do(a, {"type": "trade_gold", "amount": 50})
		var events: Array[Dictionary]
		match how:
			"decline":
				events = _do(b, {"type": "trade_cancel"})
			"too_far":
				b.move.place(Vector2i(25, 20))
				events = world.step()
			"in_combat":
				a.combat_until = world.now + 10.0
				events = world.step()
			"left":
				world.remove_hero(b.id)
				events = world.step()
		assert_eq(a.bag.count_of(helm), 1, "%s: the helm is back" % how)
		assert_eq(a.gold, 50, "%s: the gold is back" % how)
		assert_true(world.social.trade_of(a.id).is_empty(), how)


func test_bound_items_stay_out_except_bop_in_its_window_to_the_fight() -> void:
	var scroll: ItemDef = ContentDB.items[&"pebble_scroll"]
	a.bag.add(scroll, 1, {"bound": true})
	_open()
	var bound_at := a.bag.index_of(scroll)
	world.submit(a.id, {"type": "trade_add", "index": bound_at, "count": 1})
	assert_true(world.step().any(func(e): return e.type == "rejected" and e.reason == "bound"))
	a.bag.slots[bound_at].bind = Binding.on_acquire(scroll, ["Ana", "Bo"], world.now + 600.0)
	_do(a, {"type": "trade_add", "index": bound_at, "count": 1})
	assert_eq(a.bag.count_of(scroll), 0, "a looted scroll in its window goes to someone from the fight")


func test_requests_decline_themselves_and_need_range() -> void:
	b.move.place(Vector2i(25, 20))
	world.submit(a.id, {"type": "trade_request", "target": b.id})
	assert_true(world.step().any(func(e): return e.type == "rejected" and e.reason == "too_far"))
	b.move.place(Vector2i(12, 20))
	_do(a, {"type": "trade_request", "target": b.id})
	var events := world.advance(ContentDB.rules.party_play.request_seconds + 0.1)
	assert_true(events.any(func(e): return e.type == "request_declined" and e.reason == "timeout"))
	assert_true(world.social_view(b.id).requests.is_empty())


func test_a_save_mid_trade_keeps_what_is_in_escrow() -> void:
	_open()
	_do(a, {"type": "trade_add", "index": a.bag.index_of(helm), "count": 1})
	_do(a, {"type": "trade_gold", "amount": 20})
	var saved := CharacterData.capture(a)
	var back := CharacterData.restore(9, saved, ContentDB)
	assert_eq(back.bag.count_of(helm), 1)
	assert_eq(back.gold, 50)


func test_a_full_bag_refuses_the_swap_and_returns_everything() -> void:
	_open()
	_do(a, {"type": "trade_add", "index": a.bag.index_of(helm), "count": 1})
	var junk := ItemDef.new()
	junk.id = &"junk"
	b.bag.add(junk, b.bag.free_slots())
	_do(a, {"type": "trade_offer"})
	_do(b, {"type": "trade_offer"})
	_do(a, {"type": "trade_accept"})
	var events := _do(b, {"type": "trade_accept"})
	assert_true(events.any(func(e): return e.type == "trade_cancelled" and e.reason == "bag_full"))
	assert_eq(a.bag.count_of(helm), 1)
