class_name Game
extends Node
## One play session: wires the session (local or networked) to the view,
## input and HUD.

var session
var client := ClientState.new()


func start_solo() -> void:
	InputActions.ensure_registered()
	var local := LocalSession.new()
	local.name = "Session"
	add_child(local)
	var zone: ZoneDef = ContentDB.zones[&"greenfields"]
	local.start(zone, ContentDB.rules, ContentDB.heroes[&"adventurer"], randi())
	local.local_hero().display_name = "You"
	session = local
	_build_client(zone)


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
