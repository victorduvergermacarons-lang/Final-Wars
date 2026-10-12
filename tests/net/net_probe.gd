extends Node
## One side of the multi-process network check (see run_net_check.sh).
##   godot --headless --path . tests/net/net_probe.tscn -- host PORT PLAYERS
##   godot --headless --path . tests/net/net_probe.tscn -- join PORT PLAYERS INDEX
## Exits 0 if this side saw what it expected.

const TIMEOUT := 25.0

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
	game.session.local_hero().move.place(Vector2i(14, 16)) # out of the guests' way
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
	# The host only hears its own zone's events, so watch the world for zone moves.
	var watch := func():
		for id in starts:
			var sim: WorldSim = world.zone_of(id)
			if sim != null and sim.zone.id == &"greenfields":
				zone_hops[id] = true
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
	if not zone_hops.has(starts.keys()[0]):
		_finish(false, "host: Guest1 never reached Greenfields")
		return
	_finish(true, "host: %d guests joined in town, walked, cast, one went to Greenfields, all left cleanly" % (players - 1))


func _run_join(port: int, players: int, index: int) -> void:
	var game := Game.new()
	game.store = CharacterStore.new("user://netcheck_%d" % index)
	add_child(game)
	var me := "Guest%d" % index
	if game.start_join(_character(me), "127.0.0.1", port) != OK:
		_finish(false, "%s: could not start client" % me)
		return
	var session: ClientSession = game.session
	var ended_reason := [""]
	session.ended.connect(func(r): ended_reason[0] = r)
	if not await _wait_until(func(): return session.local_hero() != null or ended_reason[0] != ""):
		_finish(false, "%s: never welcomed" % me)
		return
	if session.local_hero() == null:
		_finish(false, "%s: refused: %s" % [me, ended_reason[0]])
		return
	var hero := session.local_hero()
	var hero_count := func(): return session.actors().filter(func(a): return a is Hero).size()
	if not await _wait_until(func(): return hero_count.call() == players):
		_finish(false, "%s: only ever saw %d heroes" % [me, hero_count.call()])
		return
	var heard_cast := [false]
	session.events_received.connect(func(events):
		for e in events:
			if e.type == "cast" and e.source == hero.id:
				heard_cast[0] = true)
	session.send_intent({"type": "cast", "ability": &"heal", "target": hero.id})
	# Walk up until 4 tiles from the start (other guests may be in the way at first).
	var start := hero.tile()
	var walked := func():
		var t := session.render_time()
		if not hero.move.is_moving(t) and hero.tile().y > start.y - 4:
			session.send_intent({"type": "step", "to": hero.tile() + Vector2i.UP})
		return hero.tile().y <= start.y - 4
	if not await _wait_until(walked):
		_finish(false, "%s: couldn't walk 4 tiles (at %s from %s)" % [me, hero.tile(), start])
		return
	if not await _wait_until(func(): return heard_cast[0]):
		_finish(false, "%s: never heard its own cast" % me)
		return
	await get_tree().create_timer(1.0).timeout # let the host see the final position
	for other in session.actors():
		if other is Hero and other.id != hero.id and not other.bag.slots.all(func(s): return s == null):
			_finish(false, "%s: received another player's bag" % me)
			return
	if index == 1:
		# Walk off the town's east edge: the client must switch maps.
		var switched := [false]
		session.zone_changed.connect(func(_z): switched[0] = true)
		var toward_exit := func():
			if switched[0]:
				return true
			var t := session.render_time()
			if not hero.move.is_moving(t):
				if hero.tile() == Vector2i(17, 9):
					session.send_intent({"type": "step", "to": Vector2i(18, 9)})
					return false
				var path := Pathfinder.find_path(session.grid(), hero.tile(), Vector2i(17, 9), 2,
						{}, -1, 5000)
				if path.size() >= 2:
					session.send_intent({"type": "step", "to": path[1]})
			return false
		if not await _wait_until(toward_exit):
			_finish(false, "%s: never left town (at %s)" % [me, hero.tile()])
			return
		await get_tree().create_timer(0.5).timeout
		hero = session.local_hero()
		var wolves := session.actors().filter(func(a): return a is Enemy).size()
		if session.zone().id != &"greenfields" or wolves == 0 or hero == null:
			_finish(false, "%s: after the exit: zone %s, %d wolves" % [me, session.zone().id, wolves])
			return
		await get_tree().create_timer(0.5).timeout
	game.save_now()
	var saved := game.store.load_character(me)
	if saved.get("name") != me or saved.get("bag", []).is_empty():
		_finish(false, "%s: save from the joined client is incomplete" % me)
		return
	game.store.delete(me)
	_finish(true, "%s: walked %s -> %s, sees %d heroes, saved its own hero" % [me, start, hero.tile(), players])
