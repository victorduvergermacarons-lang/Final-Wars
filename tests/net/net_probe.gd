extends Node
## One side of the two-process network check (see run_net_check.sh).
##   godot --headless --path . tests/net/net_probe.tscn -- host [port]
##   godot --headless --path . tests/net/net_probe.tscn -- join [port]
## Exits 0 if this side saw what it expected.

const TIMEOUT := 15.0

var _ok := false


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var role := args[0] if args.size() > 0 else "host"
	var port := int(args[1]) if args.size() > 1 else 7790
	if role == "host":
		_run_host(port)
	else:
		_run_join(port)


func _finish(ok: bool, msg: String) -> void:
	print("[%s] %s" % ["NETCHECK OK" if ok else "NETCHECK FAIL", msg])
	get_tree().quit(0 if ok else 1)


func _run_host(port: int) -> void:
	var game := Game.new()
	add_child(game)
	if game.start_host("Host", port) != OK:
		_finish(false, "host: could not listen on %d" % port)
		return
	var world: WorldSim = game.session.world
	var waited := 0.0
	while world.heroes().size() < 2 and waited < TIMEOUT:
		await get_tree().create_timer(0.1).timeout
		waited += 0.1
	if world.heroes().size() < 2:
		_finish(false, "host: nobody joined")
		return
	var guest: Hero = world.heroes()[1]
	var start := guest.tile()
	var cast_seen := [false]
	game.session.events_received.connect(func(events):
		for e in events:
			if e.type == "cast" and e.source == guest.id:
				cast_seen[0] = true)
	while waited < TIMEOUT and (GridModel.distance(start, guest.tile()) < 3 or not cast_seen[0]):
		await get_tree().create_timer(0.1).timeout
		waited += 0.1
	if GridModel.distance(start, guest.tile()) < 3:
		_finish(false, "host: guest '%s' did not walk (at %s)" % [guest.display_name, guest.tile()])
	elif not cast_seen[0]:
		_finish(false, "host: guest's cast never arrived")
	else:
		# Give the client time to see the final state before we drop the connection.
		await get_tree().create_timer(1.5).timeout
		_finish(true, "host: guest '%s' walked %s -> %s and cast" % [guest.display_name, start, guest.tile()])


func _run_join(port: int) -> void:
	var game := Game.new()
	add_child(game)
	if game.start_join("Guest", "127.0.0.1", port) != OK:
		_finish(false, "join: could not start client")
		return
	var session: ClientSession = game.session
	var ended_reason := [""]
	session.ended.connect(func(r): ended_reason[0] = r)
	var waited := 0.0
	while session.local_hero() == null and waited < TIMEOUT and ended_reason[0] == "":
		await get_tree().create_timer(0.1).timeout
		waited += 0.1
	if session.local_hero() == null:
		_finish(false, "join: never welcomed (%s)" % ended_reason[0])
		return
	var hero := session.local_hero()
	var start := hero.tile()
	var heard_cast := [false]
	session.events_received.connect(func(events):
		for e in events:
			if e.type == "cast" and e.source == hero.id:
				heard_cast[0] = true)
	session.send_intent({"type": "cast", "ability": &"heal", "target": hero.id})
	# Walk up 4 tiles, sending each step as soon as the last one is predicted to arrive.
	for i in 4:
		var t := session.render_time()
		while hero.move.is_moving(t):
			await get_tree().process_frame
			t = session.render_time()
		session.send_intent({"type": "step", "to": hero.tile() + Vector2i.UP})
		await get_tree().process_frame
	await get_tree().create_timer(1.0).timeout
	var heroes := session.actors().filter(func(a): return a is Hero)
	var enemies := session.actors().filter(func(a): return a is Enemy)
	var host_hero = heroes.filter(func(h): return h.id != hero.id)
	if heroes.size() != 2 or enemies.size() != 5:
		_finish(false, "join: mirror has %d heroes, %d enemies" % [heroes.size(), enemies.size()])
	elif host_hero.is_empty() or host_hero[0].display_name != "Host":
		_finish(false, "join: host hero missing or misnamed")
	elif hero.tile() != start + Vector2i.UP * 4:
		_finish(false, "join: expected to end at %s, at %s" % [start + Vector2i.UP * 4, hero.tile()])
	elif not heard_cast[0]:
		_finish(false, "join: never received our cast event")
	else:
		_finish(true, "join: walked %s -> %s, mirror has 2 heroes + 5 wolves, events arrive" % [start, hero.tile()])
