extends Node2D
## Entry scene: shows the main menu and starts/ends games.
##
## Command-line shortcuts (handy with Debug > Customize Run Instances):
##   --solo | --host | --join=ADDRESS   [--port=N] [--name=NAME]
## --name picks a saved character (created if it doesn't exist).
## Accepted with or without a "--" separator before them.

const FLAGS := ["solo", "host", "join", "port", "name"]

var _menu: MainMenu
var _game: Game
var _store := CharacterStore.new()


func _ready() -> void:
	$Title.queue_free()
	_show_menu("")
	_auto_start(OS.get_cmdline_args() + OS.get_cmdline_user_args())


func _show_menu(status: String) -> void:
	_menu = MainMenu.new()
	_menu.store = _store
	add_child(_menu)
	_menu.solo_requested.connect(_on_solo)
	_menu.host_requested.connect(_on_host)
	_menu.join_requested.connect(_on_join)
	_menu.show_status(status)


func _new_game() -> Game:
	_menu.queue_free()
	_game = Game.new()
	_game.name = "Game"
	_game.store = _store
	add_child(_game)
	_game.ended.connect(_end_game)
	return _game


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and _game != null:
		_game.save_now()


func _end_game(reason: String) -> void:
	if _game != null:
		_game.save_now()
		_game.queue_free()
		_game = null
	_show_menu.call_deferred(reason)


func _on_solo(character: Dictionary) -> void:
	_new_game().start_solo(character)


func _on_host(character: Dictionary, port: int) -> void:
	var err := _new_game().start_host(character, port)
	if err != OK:
		_end_game("Could not host on port %d (%s)." % [port, error_string(err)])


func _on_join(character: Dictionary, address: String, port: int) -> void:
	var err := _new_game().start_join(character, address, port)
	if err != OK:
		_end_game("Could not connect to %s:%d (%s)." % [address, port, error_string(err)])
	else:
		_game.client.say("Connecting to %s:%d…" % [address, port])


func _auto_start(args: PackedStringArray) -> void:
	var opts := {}
	for a in args:
		if not a.begins_with("--"):
			continue
		var parts := a.trim_prefix("--").split("=", true, 1)
		if parts[0] in FLAGS:
			opts[parts[0]] = parts[1] if parts.size() > 1 else ""
	var port := int(opts.get("port", Net.DEFAULT_PORT))
	if not (opts.has("solo") or opts.has("host") or opts.has("join")):
		return
	var character := _character_for(opts.get("name", "Adventurer"))
	if opts.has("solo"):
		_on_solo(character)
	elif opts.has("host"):
		_on_host(character, port)
	elif opts.has("join"):
		_on_join(character, opts.join if opts.join != "" else "127.0.0.1", port)


## Loads the named character, creating it if it doesn't exist yet.
func _character_for(raw_name: String) -> Dictionary:
	var char_name := CharacterData.clean_name(raw_name)
	if not _store.exists(char_name):
		_store.save(CharacterData.new_character(char_name, ContentDB.heroes[&"adventurer"]))
	return _store.load_character(char_name)
