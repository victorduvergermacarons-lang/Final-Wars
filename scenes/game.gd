class_name Game
extends Node
## One play session: wires a session (solo, host or client) to the view, input
## and HUD. All three sessions expose the same read API and send_intent().

## The session is over (connection lost, refused…); return to the menu.
signal ended(reason: String)

var session
var client := ClientState.new()
## Where the action bar layout/keybinds are saved (tests point this elsewhere).
var settings_path := SettingsStore.DEFAULT_PATH
## Where the local character is saved; null disables saving (tests).
var store: CharacterStore = null
## Where the host keeps world state (one-time events); null disables it (tests).
var world_store: WorldStore = null

const AUTOSAVE_SECONDS := 60.0
var _since_save := 0.0


func start_solo(character: Dictionary) -> void:
	InputActions.ensure_registered()
	var local := LocalSession.new()
	local.name = "Session"
	add_child(local)
	local.start(_zone(), ContentDB.rules, character, randi())
	session = local
	_load_world()
	_build_client(_zone())


func start_host(character: Dictionary, port: int) -> Error:
	InputActions.ensure_registered()
	var host := ServerSession.new()
	host.name = "Session"
	add_child(host)
	var err := host.start_hosting(_zone(), ContentDB.rules, character, port)
	if err != OK:
		return err
	session = host
	_load_world()
	_build_client(_zone())
	client.say("Hosting on port %d. Waiting for friends to join…" % port)
	return OK


## Connects; the world appears once the host has welcomed us and sent state.
func start_join(character: Dictionary, address: String, port: int) -> Error:
	InputActions.ensure_registered()
	var joiner := ClientSession.new()
	joiner.name = "Session"
	add_child(joiner)
	var err := joiner.connect_to(address, port, character)
	if err != OK:
		return err
	session = joiner
	joiner.welcomed.connect(func(): _build_client(joiner.mirror.zone), CONNECT_ONE_SHOT)
	joiner.ended.connect(func(reason): ended.emit(reason))
	return OK


## Saves the local hero to this computer (joined players save from their copy of
## the host's state, which includes their private data). The host/solo player also
## saves the world's one-time events.
func save_now() -> void:
	if session == null:
		return
	var hero: Hero = session.local_hero()
	if store != null and hero != null:
		store.save(CharacterData.capture(hero))
	if world_store != null and not (session is ClientSession):
		world_store.save(session.world.world_flags)


func _process(delta: float) -> void:
	_since_save += delta
	if _since_save >= AUTOSAVE_SECONDS:
		_since_save = 0.0
		save_now()


func _load_world() -> void:
	if world_store != null:
		session.world.world_flags = world_store.load_flags()


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
	var hud := Hud.new()
	hud.name = "Hud"
	add_child(hud)
	hud.setup(session, client, input, settings_path)
