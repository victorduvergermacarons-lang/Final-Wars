class_name Game
extends Node
## One play session: wires a session (solo, host or client) to the view, input
## and HUD. All three sessions expose the same read API and send_intent().

## The session is over (connection lost, refused…); return to the menu.
signal ended(reason: String)

var session
var client := ClientState.new()


func start_solo(player_name: String) -> void:
	InputActions.ensure_registered()
	var local := LocalSession.new()
	local.name = "Session"
	add_child(local)
	local.start(_zone(), ContentDB.rules, _hero_def(), randi())
	local.local_hero().display_name = player_name
	session = local
	_build_client(_zone())


func start_host(player_name: String, port: int) -> Error:
	InputActions.ensure_registered()
	var host := ServerSession.new()
	host.name = "Session"
	add_child(host)
	var err := host.start_hosting(_zone(), ContentDB.rules, _hero_def(), port, player_name)
	if err != OK:
		return err
	session = host
	_build_client(_zone())
	client.say("Hosting on port %d. Waiting for a friend to join…" % port)
	return OK


## Connects; the world appears once the host has welcomed us and sent state.
func start_join(player_name: String, address: String, port: int) -> Error:
	InputActions.ensure_registered()
	var joiner := ClientSession.new()
	joiner.name = "Session"
	add_child(joiner)
	var err := joiner.connect_to(address, port, player_name)
	if err != OK:
		return err
	session = joiner
	joiner.welcomed.connect(func(): _build_client(joiner.mirror.zone), CONNECT_ONE_SHOT)
	joiner.ended.connect(func(reason): ended.emit(reason))
	return OK


func _zone() -> ZoneDef:
	return ContentDB.zones[&"greenfields"]


func _hero_def() -> HeroDef:
	return ContentDB.heroes[&"adventurer"]


func _build_client(zone: ZoneDef) -> void:
	var view := WorldView.new()
	view.name = "WorldView"
	add_child(view)
	view.setup(session, client, zone)
	var input := PlayerInput.new()
	input.name = "PlayerInput"
	add_child(input)
	input.setup(session, client, view)
	var hud := DebugHud.new()
	hud.name = "DebugHud"
	add_child(hud)
	hud.setup(session, client)
