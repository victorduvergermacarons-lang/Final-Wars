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
	if not await _wait_until(func(): return world.heroes().size() == players):
		_finish(false, "host: only %d of %d players joined" % [world.heroes().size(), players])
		return
	await get_tree().create_timer(1.0).timeout # every guest is listening
	var town := world.zone(&"town")
	var guests: Array = world.heroes().slice(1)
	for i in guests.size():
		guests[i].move.place(town.find_free_tile_near(SPOT + Vector2i(i, 0)))
	game.session.local_hero().move.place(town.find_free_tile_near(SPOT + Vector2i(0, 3)))
	match scenario:
		"loot":
			await _host_loot(town, guests)
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
	if not await _wait_until(func(): return heroes.call() == players):
		_finish(false, "%s: only ever saw %d heroes" % [me, heroes.call()])
		return
	match scenario:
		"loot":
			await _join_loot(session)
		_:
			_finish(false, "%s: unknown scenario %s" % [me, scenario])
	game.store.delete(me)


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
