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
	local.start(_zones(), START_ZONE, ContentDB.rules, character, randi())
	session = local
	_load_world()
	_build_client(local.zone())


func start_host(character: Dictionary, port: int) -> Error:
	InputActions.ensure_registered()
	var host := ServerSession.new()
	host.name = "Session"
	add_child(host)
	var err := host.start_hosting(_zones(), START_ZONE, ContentDB.rules, character, port)
	if err != OK:
		return err
	session = host
	_load_world()
	_build_client(host.zone())
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


## Every zone in the game; players start (and join) in town.
const START_ZONE := &"town"


func _zones() -> Array:
	return ContentDB.zones.values()


func _hero_def() -> HeroDef:
	return ContentDB.heroes[&"adventurer"]


func _build_client(zone: ZoneDef) -> void:
	var view := _make_view(zone)
	session.zone_changed.connect(_on_zone_changed)
	var input := PlayerInput.new()
	input.name = "PlayerInput"
	add_child(input)
	input.setup(session, client, view)
	var hud := Hud.new()
	hud.name = "Hud"
	add_child(hud)
	hud.setup(session, client, input, settings_path)
	hud.leave_requested.connect(func(): ended.emit("Your hero is saved."))
	hud.act_completed.connect(func(_act): save_now()) # Act I complete: saved at once
	var sound := SoundDirector.new()
	sound.name = "SoundDirector"
	add_child(sound)
	sound.setup(session, client, view)


func _make_view(zone: ZoneDef) -> WorldView:
	var view := WorldView.new()
	view.name = "WorldView"
	add_child(view)
	move_child(view, 0) # draw the world under the HUD
	view.setup(session, client, zone)
	return view


## New map: rebuild the view for it and drop a target that stayed behind.
func _on_zone_changed(zone: ZoneDef) -> void:
	var old: WorldView = get_node_or_null("WorldView")
	if old != null:
		old.name = "OldWorldView"
		old.queue_free()
	var view := _make_view(zone)
	var input: PlayerInput = get_node_or_null("PlayerInput")
	if input != null:
		input.view = view
	var sound: SoundDirector = get_node_or_null("SoundDirector")
	if sound != null:
		sound.on_zone_changed(view)
	client.target_id = -1
	client.say("You enter %s." % zone.display_name)
