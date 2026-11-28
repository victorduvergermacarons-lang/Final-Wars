extends Node
## One side of the party check (see run_party_check.sh): a host and guests play
## one scenario of loot, boss rolls, binding, trading or duels over the network.
## The host sets the scene up (it owns the world, as in a real game) and decides
## every outcome; guests act only through intents, as players would.
##   godot --headless --path . tests/net/party_probe.tscn -- host PORT PLAYERS SCENARIO
##   godot --headless --path . tests/net/party_probe.tscn -- join PORT PLAYERS SCENARIO INDEX

const TIMEOUT := 60.0
## Open grass in Millbrook, away from its people and its boar.
const SPOT := Vector2i(12, 20)

var _waited := 0.0
var game: Game
var me := ""


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var role := args[0] if args.size() > 0 else "host"
	var port := int(args[1]) if args.size() > 1 else 7795
	var players := int(args[2]) if args.size() > 2 else 3
	var scenario := args[3] if args.size() > 3 else "loot"
	if role == "host":
		_host(port, players, scenario)
	else:
		_join(port, players, scenario, int(args[4]) if args.size() > 4 else 1)


func _finish(ok: bool, msg: String) -> void:
	print("[%s] %s" % ["PARTYCHECK OK" if ok else "PARTYCHECK FAIL", msg])
	get_tree().quit(0 if ok else 1)


func _wait_until(cond: Callable) -> bool:
	while not cond.call() and _waited < TIMEOUT:
		await get_tree().create_timer(0.1).timeout
		_waited += 0.1
	return cond.call()


func _character(char_name: String) -> Dictionary:
	return CharacterData.new_character(char_name, ContentDB.heroes[&"adventurer"])


# --- Host -------------------------------------------------------------------------

func _host(port: int, players: int, scenario: String) -> void:
	me = "Host"
	game = Game.new()
	add_child(game)
	if game.start_host(_character("Host"), port) != OK:
		_finish(false, "host: could not listen on %d" % port)
		return
	var world: World = game.session.world
	var at_start := players - 1 if scenario == "fire" else players # fire: the last guest joins late
	if not await _wait_until(func(): return world.heroes().size() == at_start):
		_finish(false, "host: only %d of %d players joined" % [world.heroes().size(), players])
		return
	await get_tree().create_timer(1.0).timeout # every guest is listening
	var town := world.zone(&"town")
	var guests: Array = world.heroes().slice(1)
	for i in guests.size():
		guests[i].move.place(town.find_free_tile_near(SPOT + Vector2i(i, 0)))
	game.session.local_hero().move.place(town.find_free_tile_near(SPOT + Vector2i(0, 3)))
	if scenario == "trade":
		game.session.events_received.connect(func(events):
			for e in events:
				if e.type == "trade_cancelled" and e.reason == "declined":
					_second_trade_over = true)
	match scenario:
		"loot":
			await _host_loot(town, guests)
		"roll":
			await _host_roll(town, guests)
		"bind":
			await _host_bind(town, guests)
		"trade":
			await _host_trade(town, guests)
		"duel":
			await _host_duel(town, guests)
		"fire":
			await _host_fire(town, guests, players)
		_:
			_finish(false, "host: unknown scenario %s" % scenario)


## Loot: a creature the guests killed drops a helm for each (personal, on the
## ground) and copies its pelts to both. Each guest picks up its own helm.
func _host_loot(town: WorldSim, guests: Array) -> void:
	var def := EnemyDef.new()
	def.id = &"party_lootling"
	def.display_name = "Lootling"
	def.stats = StatBlock.make({Stat.Id.HP: 10})
	def.aggro_radius = 0
	def.loot = LootTable.new()
	def.loot.gold_min = 7
	def.loot.gold_max = 7
	for pair in [[&"wolf_pelt", 2], [&"iron_helm", 1]]:
		var entry := LootEntry.new()
		entry.item = ContentDB.items[pair[0]]
		entry.chance = 1.0
		entry.min_count = pair[1]
		entry.max_count = pair[1]
		def.loot.entries.append(entry)
	var foe := town.add_enemy(def, guests[0].tile())
	foe.move.pos = (guests[0].move.pos + guests[1].move.pos) * 0.5
	for g in guests:
		foe.threat.add(g.id, 1.0)
	foe.state = Enemy.State.COMBAT
	var events: Array[Dictionary] = []
	AbilityResolver.deal_damage(town.ctx, guests[0], foe, &"test", 1000.0, false, events)
	town._emit_resolved(events)
	var helm: ItemDef = ContentDB.items[&"iron_helm"]
	var picked := func():
		for g in guests:
			if g.bag.count_of(helm) < 1 or not town.drops.for_owner(g.id).is_empty():
				return false
		return true
	if not await _wait_until(picked):
		_finish(false, "host: the guests' helms were never picked up")
		return
	for g in guests:
		if g.gold < 7 or g.bag.count_of(ContentDB.items[&"wolf_pelt"]) != 2:
			_finish(false, "host: %s didn't get the shared gold and pelts" % g.display_name)
			return
	await get_tree().create_timer(1.5).timeout
	_finish(true, "host: a kill gave each guest its own helm on the ground (picked up by each) and copied 7 gold and 2 pelts to both")


## Boss roll: an elite drops a helm; Guest1 rolls Need, Guest2 Greed (through their
## roll windows), the host never answers (a timeout pass, no bonus). Need wins.
func _host_roll(town: WorldSim, guests: Array) -> void:
	var pp: PartyPlayDef = town.rules.party_play
	pp.roll_seconds = 6.0 # a short timer so the host's silence settles it quickly
	var host: Hero = game.session.local_hero()
	host.move.place(town.find_free_tile_near(SPOT + Vector2i(2, 0)))
	var def := EnemyDef.new()
	def.id = &"party_boss"
	def.display_name = "Party Boss"
	def.elite = true
	def.stats = StatBlock.make({Stat.Id.HP: 10})
	def.aggro_radius = 0
	def.loot = LootTable.new()
	var entry := LootEntry.new()
	entry.item = ContentDB.items[&"iron_helm"]
	entry.chance = 1.0
	def.loot.entries = [entry]
	var foe := town.add_enemy(def, SPOT + Vector2i(0, -2))
	for h in guests + [host]:
		foe.threat.add(h.id, 1.0)
	foe.state = Enemy.State.COMBAT
	var events: Array[Dictionary] = []
	AbilityResolver.deal_damage(town.ctx, guests[0], foe, &"test", 1000.0, false, events)
	town._emit_resolved(events)
	var helm: ItemDef = ContentDB.items[&"iron_helm"]
	if not await _wait_until(func(): return guests[0].bag.count_of(helm) == 1):
		_finish(false, "host: the Need roller never got the helm")
		return
	if guests[1].bag.count_of(helm) != 0 or host.bag.count_of(helm) != 0:
		_finish(false, "host: the helm went to someone else too")
		return
	if guests[1].loot_bonus != 0 or host.loot_bonus != 0 or guests[0].loot_bonus != 0:
		_finish(false, "host: bonuses wrong: %d %d %d" % [guests[0].loot_bonus, guests[1].loot_bonus, host.loot_bonus])
		return
	await get_tree().create_timer(1.5).timeout
	_finish(true, "host: Guest1 rolled Need, Guest2 Greed, the host timed out; Need won the helm, no bonus for the silent host or the lost Greed")


## Binding: a scroll drops for each guest from a fight they shared; looted, it is
## bound with a trade window for that fight's members. A helm stays free until worn.
func _host_bind(town: WorldSim, guests: Array) -> void:
	var names: Array = guests.map(func(g): return g.display_name)
	var scroll: ItemDef = ContentDB.items[&"pebble_scroll"]
	for g in guests:
		g.bag.remove_item(scroll, g.bag.count_of(scroll))
		town.drops.add(g.id, scroll, 1, g.move.pos, town.now + 300.0, &"test", names)
		town.drops.add(g.id, ContentDB.items[&"iron_helm"], 1, g.move.pos, town.now + 300.0, &"test", names)
	var done := func():
		for g in guests:
			if g.bag.count_of(scroll) != 1 or g.bag.count_of(ContentDB.items[&"iron_helm"]) != 1:
				return false
		return true
	if not await _wait_until(done):
		_finish(false, "host: the guests never looted their scroll and helm")
		return
	for g in guests:
		var b: Dictionary = g.bag.bind_at(g.bag.index_of(scroll))
		if not Binding.can_trade(b, names[1 - guests.find(g)], town.now) or Binding.can_trade(b, "Host", town.now):
			_finish(false, "host: %s's scroll window is wrong: %s" % [g.display_name, b])
			return
	await get_tree().create_timer(1.5).timeout
	_finish(true, "host: each guest's looted scroll is bound, tradeable only to the other guest from that fight")


## Trading: Guest1 gives a helm and 5 gold for Guest2's 3 pelts (request, both
## windows, offer, contract, accept). Then a second trade is declined at the
## contract and everything goes back.
func _host_trade(town: WorldSim, guests: Array) -> void:
	var helm: ItemDef = ContentDB.items[&"iron_helm"]
	var pelt: ItemDef = ContentDB.items[&"wolf_pelt"]
	guests[0].bag.add(helm)
	guests[0].gold = 20
	guests[1].bag.add(pelt, 3)
	guests[1].gold = 0
	var traded := func(): return guests[1].bag.count_of(helm) == 1 and guests[0].bag.count_of(pelt) == 3
	if not await _wait_until(traded):
		_finish(false, "host: the first trade never completed")
		return
	if guests[0].gold != 15 or guests[1].gold != 5:
		_finish(false, "host: gold after the trade: %d / %d" % [guests[0].gold, guests[1].gold])
		return
	var back := func(): return _second_trade_over and town.social.trades.is_empty() \
			and guests[1].bag.count_of(helm) == 1 and guests[0].bag.count_of(pelt) == 3
	if not await _wait_until(back):
		_finish(false, "host: the second trade didn't end with everything back")
		return
	await get_tree().create_timer(1.0).timeout
	_finish(true, "host: a helm and 5 gold went for 3 pelts in one go; a second trade, declined at the contract, returned everything")


## Duel: Guest1 challenges Guest2; once the fight is on, the host (as the world)
## brings Guest2 low so one Fire Punch from Guest1 makes them yield at 1 HP.
## The host, a bystander near the flag, hears who won.
func _host_duel(town: WorldSim, guests: Array) -> void:
	var heard := [""]
	game.session.events_received.connect(func(events):
		for e in events:
			if e.type == "duel_end":
				heard[0] = "%s has defeated %s in a duel." % [e.winner_name, e.loser_name])
	if not await _wait_until(func(): return guests[1].duel_live):
		_finish(false, "host: the duel never started")
		return
	guests[1].hp = 6.0
	if not await _wait_until(func(): return heard[0] != ""):
		_finish(false, "host: never heard the duel end")
		return
	if heard[0] != "Guest1 has defeated Guest2 in a duel." or not guests[1].alive or guests[1].hp > 2.0:
		_finish(false, "host: %s, Guest2 alive %s at %s HP" % [heard[0], guests[1].alive, guests[1].hp])
		return
	await get_tree().create_timer(1.5).timeout
	_finish(true, "host: duel ran (flag, countdown, fight); Guest2 yielded at 1 HP alive; the host nearby heard: %s" % heard[0])


## Set by watching the host's own world for the second trade's cancel.
var _second_trade_over := false


# --- Guests -------------------------------------------------------------------------

func _join(port: int, players: int, scenario: String, index: int) -> void:
	me = "Guest%d" % index
	game = Game.new()
	game.store = CharacterStore.new("user://partycheck_%d" % index)
	add_child(game)
	if game.start_join(_character(me), "127.0.0.1", port) != OK:
		_finish(false, "%s: could not start client" % me)
		return
	var session: ClientSession = game.session
	if not await _wait_until(func(): return session.local_hero() != null):
		_finish(false, "%s: never welcomed" % me)
		return
	var heroes := func(): return session.actors().filter(func(a): return a is Hero).size()
	var want := players - 1 if (scenario == "fire" and index < players - 1) else players
	if not await _wait_until(func(): return heroes.call() >= want):
		_finish(false, "%s: only ever saw %d heroes" % [me, heroes.call()])
		return
	match scenario:
		"loot":
			await _join_loot(session)
		"roll":
			await _join_roll(session, index)
		"bind":
			await _join_bind(session)
		"trade":
			await _join_trade(session, index)
		"duel":
			await _join_duel(session, index)
		"fire":
			await _join_fire(session, index)
		_:
			_finish(false, "%s: unknown scenario %s" % [me, scenario])
	game.store.delete(me)


func _join_roll(session: ClientSession, index: int) -> void:
	var hud: Hud = game.get_node("Hud")
	var lines: Array = []
	session.events_received.connect(func(events):
		for e in events:
			if e.type == "roll_result":
				lines.append_array(Array(Hud.roll_lines(e))))
	if not await _wait_until(func(): return not hud.roll_window.showing().is_empty()):
		_finish(false, "%s: no roll window ever opened" % me)
		return
	var id: int = hud.roll_window.showing()[0]
	hud.roll_window.choose(id, "need" if index == 1 else "greed")
	if not await _wait_until(func(): return lines.size() >= 4):
		_finish(false, "%s: never heard the roll's result" % me)
		return
	var text := "\n".join(lines)
	for want in ["Guest1: Need", "Guest2: Greed", "Host: Pass (no answer)", "Guest1 wins Iron Helm."]:
		if not text.contains(want):
			_finish(false, "%s: the feed lacks '%s': %s" % [me, want, text])
			return
	var helm: ItemDef = ContentDB.items[&"iron_helm"]
	var has := session.local_hero().bag.count_of(helm)
	if (index == 1) != (has == 1):
		_finish(false, "%s: helm in bag: %d" % [me, has])
		return
	_finish(true, "%s: answered in its roll window, saw every roll in the feed (%s)" % [me, " / ".join(lines)])


func _join_bind(session: ClientSession) -> void:
	if not await _wait_until(func(): return session.my_drops().size() == 2):
		_finish(false, "%s: our two drops never showed" % me)
		return
	for d in session.my_drops():
		session.send_intent({"type": "pick_up", "drop": d.id})
	var scroll: ItemDef = ContentDB.items[&"pebble_scroll"]
	var helm: ItemDef = ContentDB.items[&"iron_helm"]
	var hero := func() -> Hero: return session.local_hero()
	if not await _wait_until(func(): return hero.call().bag.count_of(scroll) == 1 and hero.call().bag.count_of(helm) == 1):
		_finish(false, "%s: never got the scroll and helm" % me)
		return
	var bag: Bag = hero.call().bag
	var tip := ItemTooltip.text(scroll, hero.call(), session.rules(), false, session.now(), bag.bind_at(bag.index_of(scroll)))
	if not tip.contains("Soulbound") or not tip.contains("Tradeable to"):
		_finish(false, "%s: the scroll's tooltip lacks its binding: %s" % [me, tip])
		return
	var helm_tip := ItemTooltip.text(helm, hero.call(), session.rules(), false, session.now(), bag.bind_at(bag.index_of(helm)))
	if not helm_tip.contains("Bind on Equip"):
		_finish(false, "%s: the helm's tooltip lacks Bind on Equip" % me)
		return
	_finish(true, "%s: its client shows the looted scroll Soulbound with its trade window, the helm Bind on Equip" % me)


func _join_trade(session: ClientSession, index: int) -> void:
	var hud: Hud = game.get_node("Hud")
	var hero := func() -> Hero: return session.local_hero()
	var other := func() -> Hero:
		for a in session.actors():
			if a is Hero and a.display_name == ("Guest2" if index == 1 else "Guest1"):
				return a
		return null
	var helm: ItemDef = ContentDB.items[&"iron_helm"]
	var pelt: ItemDef = ContentDB.items[&"wolf_pelt"]
	var has_goods := func(): return hero.call().bag.count_of(helm if index == 1 else pelt) >= 1
	if not await _wait_until(has_goods):
		_finish(false, "%s: the host never gave us our goods" % me)
		return
	for round in 2:
		if index == 1:
			await get_tree().create_timer(0.5).timeout
			hud.ask(other.call().id, "trade") # as the right-click menu does
		else:
			if not await _wait_until(func(): return hud.request_window.showing() >= 0):
				_finish(false, "%s: no trade request window (round %d)" % [me, round + 1])
				return
			hud.request_window.answer(true)
		if not await _wait_until(func(): return hud.trade_window.visible):
			_finish(false, "%s: the trade window never opened (round %d)" % [me, round + 1])
			return
		var bag: Bag = hero.call().bag
		if round == 0:
			var mine := helm if index == 1 else pelt
			session.send_intent({"type": "trade_add", "index": bag.index_of(mine), "count": bag.count_at(bag.index_of(mine))})
			if index == 1:
				session.send_intent({"type": "trade_gold", "amount": 5})
		else:
			var mine := pelt if index == 1 else helm
			session.send_intent({"type": "trade_add", "index": bag.index_of(mine), "count": 1})
		var theirs_in := func():
			var t := hud.trade_window.trade()
			return not t.is_empty() and not t.theirs.items.is_empty() and not t.mine.items.is_empty()
		if not await _wait_until(theirs_in):
			_finish(false, "%s: both sides never filled (round %d)" % [me, round + 1])
			return
		await get_tree().create_timer(0.3).timeout
		session.send_intent({"type": "trade_offer"})
		if not await _wait_until(func(): return hud.trade_window.trade().get("stage", "") == "contract"):
			_finish(false, "%s: the contract never showed (round %d)" % [me, round + 1])
			return
		var contract := TradeWindow.contract_text(hud.trade_window.trade())
		if round == 0:
			var want := "Wolf Pelt x3" if index == 1 else "Iron Helm, 5 gold"
			if not contract.contains("You get from %s:[/b] %s" % [other.call().display_name, want]):
				_finish(false, "%s: the contract reads %s" % [me, contract])
				return
			session.send_intent({"type": "trade_accept"})
			var got := func(): return hero.call().bag.count_of(pelt if index == 1 else helm) >= 1 \
					and not hud.trade_window.visible
			if not await _wait_until(got):
				_finish(false, "%s: never received our side of the trade" % me)
				return
		else:
			if index == 2:
				hud.trade_window.cancel() # Decline at the contract
			if not await _wait_until(func(): return not hud.trade_window.visible):
				_finish(false, "%s: the declined trade stayed open" % me)
				return
			await get_tree().create_timer(0.5).timeout
			var back := pelt if index == 1 else helm
			if hero.call().bag.count_of(back) < 1:
				_finish(false, "%s: our item never came back after the decline" % me)
				return
	_finish(true, "%s: traded through the request, trade and contract windows; a declined contract gave everything back" % me)


func _join_duel(session: ClientSession, index: int) -> void:
	var hud: Hud = game.get_node("Hud")
	var hero := func() -> Hero: return session.local_hero()
	var foe_id := func() -> int:
		for a in session.actors():
			if a is Hero and a.display_name == ("Guest2" if index == 1 else "Guest1"):
				return a.id
		return -1
	var said: Array = []
	session.events_received.connect(func(events):
		for e in events:
			if e.type == "duel_end":
				said.append("%s has defeated %s in a duel." % [e.winner_name, e.loser_name]))
	if index == 1:
		await get_tree().create_timer(0.5).timeout
		hud.ask(foe_id.call(), "duel")
	else:
		if not await _wait_until(func(): return hud.request_window.showing() >= 0):
			_finish(false, "%s: no duel request window" % me)
			return
		hud.request_window.answer(true)
	if not await _wait_until(func(): return not session.duels().is_empty()):
		_finish(false, "%s: never saw the duel flag" % me)
		return
	var d: Dictionary = session.duels()[0]
	if d.state != "countdown":
		_finish(false, "%s: the duel didn't start with a countdown" % me)
		return
	if not await _wait_until(func(): return hero.call().duel_live):
		_finish(false, "%s: the fight never began on our side" % me)
		return
	var lowest := [INF]
	get_tree().process_frame.connect(func():
		if session.local_hero() != null:
			lowest[0] = minf(lowest[0], session.local_hero().hp))
	if index == 1:
		# Fire Punch the other duelist (adjacent) until the duel ends.
		while said.is_empty() and _waited < TIMEOUT:
			session.send_intent({"type": "cast", "ability": &"F01", "target": foe_id.call()})
			await get_tree().create_timer(0.5).timeout
			_waited += 0.5
	if not await _wait_until(func(): return not said.is_empty()):
		_finish(false, "%s: never heard the duel end" % me)
		return
	if said[0] != "Guest1 has defeated Guest2 in a duel.":
		_finish(false, "%s: heard %s" % [me, said[0]])
		return
	await get_tree().create_timer(0.5).timeout
	if index == 2 and (not hero.call().alive or absf(lowest[0] - 1.0) > 0.01):
		_finish(false, "%s: expected to yield at 1 HP alive; lowest %s" % [me, lowest[0]])
		return
	if hero.call().duel_with != -1:
		_finish(false, "%s: still marked in a duel" % me)
		return
	_finish(true, "%s: requested/accepted through the windows, saw the flag and countdown, %s" % [me,
			"won with Fire Punch" if index == 1 else "yielded at 1 HP, still alive"])


func _join_loot(session: ClientSession) -> void:
	var hero := session.local_hero()
	var others_looted := [false]
	session.events_received.connect(func(events):
		for e in events:
			if e.type == "looted" and e.source != hero.id and e.item == "iron_helm":
				others_looted[0] = true)
	if not await _wait_until(func(): return not session.my_drops().is_empty()):
		_finish(false, "%s: no drop of our own ever showed" % me)
		return
	var mine: Array = session.my_drops()
	if mine.size() != 1 or mine[0].item != "iron_helm":
		_finish(false, "%s: expected exactly our own helm on the ground, saw %s" % [me, mine])
		return
	await get_tree().create_timer(0.3).timeout
	session.send_intent({"type": "pick_up", "drop": mine[0].id})
	var helm: ItemDef = ContentDB.items[&"iron_helm"]
	if not await _wait_until(func(): return session.local_hero().bag.count_of(helm) == 1):
		_finish(false, "%s: the helm never reached our bag" % me)
		return
	if session.local_hero().bag.count_of(ContentDB.items[&"wolf_pelt"]) != 2:
		_finish(false, "%s: the shared pelts never reached our bag" % me)
		return
	if not await _wait_until(func(): return others_looted[0]):
		_finish(false, "%s: never heard the other guest loot their helm (party feed)" % me)
		return
	_finish(true, "%s: saw only its own drop, picked it up, got the shared pelts, heard the other guest's pickup" % me)


# --- Fire physics (phase 4): the same ground fire for everyone, late joiners too -----

## The burning zones as everyone should see them: "ability:tiles:until" per fire zone.
static func fire_signature(zones: Array) -> String:
	var parts: PackedStringArray = []
	for z in zones:
		if not FireEffects.GROUND_LOOKS.has(StringName(z.ability)):
			continue
		var tiles: Array = z.tiles.duplicate()
		tiles.sort()
		parts.append("%s:%s:%.2f" % [z.ability, str(tiles), float(z.until)])
	parts.sort()
	return "|".join(parts)


## Host: two overlapping Infernos and a Burning Ground near the guests; then the last
## guest joins while they burn. Prints the burning zones it owns.
func _host_fire(town: WorldSim, guests: Array, players: int) -> void:
	var hero: Hero = game.session.local_hero()
	for id in [&"F08", &"F16"]:
		TreeRules.master(hero, ContentDB.abilities[id])
	var c := SPOT + Vector2i(2, -3)
	var cast := func(id: StringName, at: Vector2) -> void:
		hero.mana = 999.0
		hero.cooldowns = Cooldowns.new()
		game.session.send_intent({"type": "cast", "ability": id, "target": -1, "aim": at})
	cast.call(&"F16", Vector2(c))
	await get_tree().create_timer(1.5).timeout
	cast.call(&"F16", Vector2(c) + Vector2(1.5, 0.5))
	await get_tree().create_timer(0.5).timeout
	cast.call(&"F08", Vector2(c) + Vector2(-1, 2))
	if not await _wait_until(func(): return game.session.world.heroes().size() == players):
		_finish(false, "host: the late guest never joined")
		return
	await get_tree().create_timer(1.0).timeout
	print("FIRESIG host %s" % fire_signature(town.ground_zones()))
	var view: WorldView = game.get_node("WorldView")
	print("FIREWINDOWS host %d" % view.fire.effects.size())
	await get_tree().create_timer(2.0).timeout
	_finish(true, "host: cast two overlapping Infernos and a Burning Ground; the last guest joined while they burned")


## Guests: the zones in their snapshots match the host's, and their own fire windows
## hold exactly those tiles until those times (late joiner included).
func _join_fire(session: ClientSession, index: int) -> void:
	var view: WorldView = game.get_node("WorldView")
	if not await _wait_until(func(): return fire_signature(session.ground_zones()).contains("F08")):
		_finish(false, "%s: never saw the Burning Ground" % me)
		return
	await get_tree().create_timer(0.3).timeout
	var zones := session.ground_zones()
	print("FIRESIG %s %s" % [me, fire_signature(zones)])
	# Every burning tile is in one of our fire windows, until the host's time.
	for z in zones:
		if not FireEffects.GROUND_LOOKS.has(StringName(z.ability)):
			continue
		for t in z.tiles:
			var found := false
			for e in view.fire.effects:
				if e.ground_until.has(t) and absf(float(e.ground_until[t]) - float(z.until)) < 0.01 or \
						(e.ground_until.has(t) and float(e.ground_until[t]) >= float(z.until)):
					found = true
			if not found:
				_finish(false, "%s: tile %s of %s isn't in any fire window" % [me, t, z.ability])
				return
	print("FIREWINDOWS %s %d" % [me, view.fire.effects.size()])
	_finish(true, "%s: its fire windows hold every burning tile until the host's time%s" % [me, " (joined late)" if index == 2 else ""])
