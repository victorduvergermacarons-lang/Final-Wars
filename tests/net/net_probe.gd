extends Node
## One side of the multi-process network check (see run_net_check.sh).
##   godot --headless --path . tests/net/net_probe.tscn -- host PORT PLAYERS
##   godot --headless --path . tests/net/net_probe.tscn -- join PORT PLAYERS INDEX
## Exits 0 if this side saw what it expected.

const TIMEOUT := 25.0
## The quest the host shares with the guests in town.
const QUEST := &"wolves_at_the_gate"

var _waited := 0.0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var role := args[0] if args.size() > 0 else "host"
	var port := int(args[1]) if args.size() > 1 else 7790
	var players := int(args[2]) if args.size() > 2 else 2
	if role == "host":
		_run_host(port, players)
	else:
		_run_join(port, players, int(args[3]) if args.size() > 3 else 1)


func _finish(ok: bool, msg: String) -> void:
	print("[%s] %s" % ["NETCHECK OK" if ok else "NETCHECK FAIL", msg])
	get_tree().quit(0 if ok else 1)


func _wait_until(cond: Callable) -> bool:
	while not cond.call() and _waited < TIMEOUT:
		await get_tree().create_timer(0.1).timeout
		_waited += 0.1
	return cond.call()


func _character(char_name: String) -> Dictionary:
	return CharacterData.new_character(char_name, ContentDB.heroes[&"adventurer"])


func _run_host(port: int, players: int) -> void:
	var game := Game.new()
	add_child(game)
	if game.start_host(_character("Host"), port) != OK:
		_finish(false, "host: could not listen on %d" % port)
		return
	var world: World = game.session.world
	# Beside Captain Rowan (by the south gate), out of the guests' way.
	var town := world.zone(&"town")
	var board: Npc = town.npcs().filter(func(n): return n.def.id == &"rowan")[0]
	game.session.local_hero().move.place(town.find_free_tile_near(board.tile() + Vector2i(-1, 0)))
	# Listen from the start: a quick guest may cast before the others have joined.
	var casts := {}
	var zone_hops := {}
	game.session.events_received.connect(func(events):
		for e in events:
			if e.type == "cast":
				casts[e.source] = true)
	if not await _wait_until(func(): return world.heroes().size() == players):
		_finish(false, "host: only %d of %d players joined" % [world.heroes().size(), players])
		return
	var starts := {}
	for h in world.heroes().slice(1):
		starts[h.id] = h.tile()
	# Co-op: the host takes Rowan's quest; the guests in town are offered it
	# and join over the network (once the last one to join is listening).
	await get_tree().create_timer(1.0).timeout
	game.session.send_intent({"type": "accept_quest", "npc": board.id, "quest": QUEST})
	var joined_quest := {}
	get_tree().process_frame.connect(func():
		for h in world.heroes():
			if QuestLog.is_active(h, QUEST):
				joined_quest[h.id] = true)
	# The host only hears its own zone's events, so watch the world for zone moves:
	# Guest1 goes to Greenfields, Guest2 to the Crossing, while the host stays in town.
	var watch := func():
		for id in starts:
			var sim: WorldSim = world.zone_of(id)
			if sim != null and sim.zone.id != &"town":
				zone_hops[id] = sim.zone.id
	get_tree().process_frame.connect(watch)
	var all_done := func():
		for id in starts:
			var h: Actor = world.get_actor(id)
			if h == null or GridModel.distance(starts[id], h.tile()) < 3 or not casts.has(id):
				return false
		return true
	if not await _wait_until(all_done):
		_finish(false, "host: not every guest walked and cast")
		return
	# Guests quit after their own checks; each hero must leave the world cleanly.
	if not await _wait_until(func(): return world.heroes().size() == 1):
		_finish(false, "host: %d heroes still in the world after guests left" % world.heroes().size())
		return
	var stuck := world.enemies().filter(func(e): return e.threat.ids().any(func(id): return id != world.heroes()[0].id))
	if not stuck.is_empty():
		_finish(false, "host: an enemy still lists a departed hero")
		return
	if zone_hops.get(starts.keys()[0]) != &"greenfields":
		_finish(false, "host: Guest1 never reached Greenfields")
		return
	if players >= 3 and zone_hops.get(starts.keys()[1]) != &"crossing":
		_finish(false, "host: Guest2 never reached the Crossing")
		return
	for id in starts.keys().slice(1):
		if not joined_quest.has(id):
			_finish(false, "host: a guest in town never joined the shared quest")
			return
	_finish(true, "host: %d guests joined in town, walked, cast, one went to Greenfields and one to the Crossing (three zones at once), the others joined the host's quest, all left cleanly" % (players - 1))


func _run_join(port: int, players: int, index: int) -> void:
	var game := Game.new()
	game.store = CharacterStore.new("user://netcheck_%d" % index)
	add_child(game)
	var me := "Guest%d" % index
	if game.start_join(_character(me), "127.0.0.1", port) != OK:
		_finish(false, "%s: could not start client" % me)
		return
	var session: ClientSession = game.session
	session.send_delay = float(OS.get_environment("NETCHECK_DELAY")) if OS.get_environment("NETCHECK_DELAY") != "" else 0.0
	var predicted_error := [0.0]
	var ended_reason := [""]
	session.ended.connect(func(r): ended_reason[0] = r)
	if not await _wait_until(func(): return session.local_hero() != null or ended_reason[0] != ""):
		_finish(false, "%s: never welcomed" % me)
		return
	if session.local_hero() == null:
		_finish(false, "%s: refused: %s" % [me, ended_reason[0]])
		return
	var hero := session.local_hero()
	# Co-op: when the host accepts a quest, it's offered to us: join it.
	session.events_received.connect(func(events):
		for e in events:
			if e.type == "quest_shared" and e.target == hero.id:
				session.send_intent({"type": "accept_shared_quest", "quest": e.quest}))
	var hero_count := func(): return session.actors().filter(func(a): return a is Hero).size()
	if not await _wait_until(func(): return hero_count.call() == players):
		_finish(false, "%s: only ever saw %d heroes" % [me, hero_count.call()])
		return
	var heard_cast := [false]
	session.events_received.connect(func(events):
		for e in events:
			if e.type == "cast" and e.source == hero.id:
				heard_cast[0] = true)
	# Put Mender's Scroll in the learning slot (private state), then cast Healing
	# Touch on yourself.
	session.send_intent({"type": "learn", "bag_index": hero.bag.index_of(ContentDB.items[&"menders_scroll"])})
	if not await _wait_until(func(): return hero.learning_item != null and hero.learning_item.id == &"menders_scroll"):
		_finish(false, "%s: couldn't learn from a scroll" % me)
		return
	session.send_intent({"type": "cast", "ability": &"W01", "target": hero.id})
	# Healing Touch runs a timing bar, and moving would cancel it: with no press it
	# goes off (at miss power) when the bar ends, so wait for that before walking.
	if not await _wait_until(func(): return heard_cast[0]):
		_finish(false, "%s: never heard its own cast" % me)
		return
	# Free movement: walk each of the 8 screen directions (predicted on this
	# machine), stop, and check this machine and the host agree on where we are.
	var start := hero.tile()
	for dir in [Vector2i(0, -1), Vector2i(1, -1), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1),
			Vector2i(-1, 1), Vector2i(-1, 0), Vector2i(-1, -1)]:
		var from := hero.move.pos
		for i in 6: # 0.3 s: one move intent per tick while the key is held
			session.send_intent({"type": "move", "dir": dir, "face": 0.0})
			await get_tree().create_timer(0.05).timeout
		if hero.move.pos.distance_to(from) < 0.2:
			# Someone may stand in the way; only fail if nothing moved at all.
			print("%s: blocked walking %s" % [me, dir])
	session.send_intent({"type": "move", "dir": Vector2i.ZERO, "face": 0.0})
	await get_tree().create_timer(0.6 + session.send_delay * 2.0).timeout
	var error := hero.move.pos.distance_to(session.mirror.last_host_pos)
	if error > 0.25:
		_finish(false, "%s: predicted %s but the host says %s (%.2f tiles apart)" % [me, hero.move.pos, session.mirror.last_host_pos, error])
		return
	# Then up the screen for 1.5 s, at least 3 tiles from the start.
	for i in 30:
		session.send_intent({"type": "move", "dir": Vector2i(0, -1), "face": 0.0})
		await get_tree().create_timer(0.05).timeout
	session.send_intent({"type": "move", "dir": Vector2i.ZERO, "face": 0.0})
	if GridModel.distance(start, hero.tile()) < 3:
		_finish(false, "%s: couldn't walk away from %s (at %s)" % [me, start, hero.tile()])
		return
	predicted_error[0] = error
	await get_tree().create_timer(1.0).timeout # let the host see the final position
	if index >= 2 and not await _wait_until(func(): return QuestLog.is_active(hero, QUEST)):
		_finish(false, "%s: never joined the host's quest" % me)
		return
	if index == 3 and not await _dodge(session, hero, me):
		return
	for other in session.actors():
		if other is Hero and other.id != hero.id and not other.bag.slots.all(func(s): return s == null):
			_finish(false, "%s: received another player's bag" % me)
			return
	if index == 1 or index == 2:
		# Guest1 walks off the town's east edge (Greenfields), Guest2 off its south
		# gate (the Crossing): the client must switch maps.
		var w: int = session.grid().width
		var edge := Vector2i(w - 1, 9) if index == 1 else Vector2i(9, session.grid().depth - 1)
		var beyond := edge + (Vector2i.RIGHT if index == 1 else Vector2i.DOWN)
		var switched := [false]
		session.zone_changed.connect(func(_z): switched[0] = true)
		var toward_exit := func():
			if switched[0]:
				return true
			var t := session.render_time()
			if not hero.move.is_moving(t):
				if hero.tile() == edge:
					session.send_intent({"type": "step", "to": beyond})
					return false
				var path := Pathfinder.find_path(session.grid(), hero.tile(), edge, 2,
						{}, -1, 5000)
				if path.size() >= 2:
					session.send_intent({"type": "step", "to": path[1]})
			return false
		if not await _wait_until(toward_exit):
			_finish(false, "%s: never left town (at %s)" % [me, hero.tile()])
			return
		await get_tree().create_timer(0.5).timeout
		hero = session.local_hero()
		if index == 1:
			var wolves := session.actors().filter(func(a): return a is Enemy).size()
			if session.zone().id != &"greenfields" or wolves == 0 or hero == null:
				_finish(false, "%s: after the exit: zone %s, %d wolves" % [me, session.zone().id, wolves])
				return
		else:
			var board := session.actors().filter(func(a): return a is Npc and a.def.id == &"guild_board")
			if session.zone().id != &"crossing" or board.is_empty() or hero == null:
				_finish(false, "%s: after the gate: zone %s, Guild Board seen: %s" % [me, session.zone().id, not board.is_empty()])
				return
		await get_tree().create_timer(0.5).timeout
	game.save_now()
	var saved := game.store.load_character(me)
	if saved.get("name") != me or saved.get("bag", []).is_empty():
		_finish(false, "%s: save from the joined client is incomplete" % me)
		return
	game.store.delete(me)
	_finish(true, "%s: walked 8 directions and on (%s -> %s), prediction within %.2f tiles of the host%s, sees %d heroes, saved its own hero%s" % [me, start, hero.tile(), predicted_error[0], " (%d ms delay)" % roundi(session.send_delay * 1000.0) if session.send_delay > 0.0 else "", players, ", dodged a Bandit Brute's telegraphed swipe" if _dodged else ""])


var _dodged := false


## Free movement: a Bandit Brute (spawned beside us with the debug console) winds
## up its telegraphed swipe; we run straight away over the network and it misses.
func _dodge(session: ClientSession, hero: Hero, me: String) -> bool:
	var windup := [-1]
	var hit := [false]
	session.events_received.connect(func(events):
		for e in events:
			if e.type == "cast_start" and e.get("kind", "") == "windup" and e.get("ability", &"") == &"crushing_blow":
				windup[0] = e.source
			if e.type == "damage" and e.target == hero.id and e.get("ability", &"") == &"crushing_blow":
				hit[0] = true)
	# Away from the others (a brute in town could pull a guest walking past into
	# combat, and nobody leaves a zone in combat): the Enemy Testing Grounds.
	var arrived := [false]
	session.zone_changed.connect(func(_z): arrived[0] = true)
	session.send_intent({"type": "debug", "line": "goto enemy_testing"})
	if not await _wait_until(func(): return arrived[0] and session.local_hero() != null):
		_finish(false, "%s: couldn't go to the testing grounds" % me)
		return false
	await get_tree().create_timer(0.3).timeout
	hero = session.local_hero()
	session.send_intent({"type": "debug", "line": "spawn bandit_brute 1 1"})
	if not await _wait_until(func(): return windup[0] >= 0):
		_finish(false, "%s: no brute ever wound up a swipe at us" % me)
		return false
	var brute: Actor = session.get_actor(windup[0])
	var away: Vector2 = (hero.move.pos - brute.move.pos).normalized()
	var best := Vector2i.ZERO
	for dir in [Vector2i(0, -1), Vector2i(1, -1), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1),
			Vector2i(-1, 1), Vector2i(-1, 0), Vector2i(-1, -1)]:
		if best == Vector2i.ZERO or Mover.screen_to_grid(dir).dot(away) > Mover.screen_to_grid(best).dot(away):
			best = dir
	for i in 24: # 1.2 s: out of the swipe, then out of reach of a slow brute
		session.send_intent({"type": "move", "dir": best, "face": 0.0})
		await get_tree().create_timer(0.05).timeout
	session.send_intent({"type": "move", "dir": Vector2i.ZERO, "face": 0.0})
	await get_tree().create_timer(0.3).timeout
	if hit[0]:
		_finish(false, "%s: ran from the telegraphed swipe but was hit" % me)
		return false
	_dodged = true
	return true
