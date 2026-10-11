extends Node2D
## Entry scene: shows the main menu and starts/ends games.
##
## Command-line shortcuts (handy with Debug > Customize Run Instances), passed
## after "--":  --solo | --host | --join=ADDRESS   [--port=N] [--name=NAME]

var _menu: MainMenu
var _game: Game


func _ready() -> void:
	$Title.queue_free()
	_show_menu("")
	_auto_start(OS.get_cmdline_user_args())


func _show_menu(status: String) -> void:
	_menu = MainMenu.new()
	add_child(_menu)
	_menu.solo_requested.connect(_on_solo)
	_menu.host_requested.connect(_on_host)
	_menu.join_requested.connect(_on_join)
	_menu.show_status(status)


func _new_game() -> Game:
	_menu.queue_free()
	_game = Game.new()
	_game.name = "Game"
	add_child(_game)
	_game.ended.connect(_end_game)
	return _game


func _end_game(reason: String) -> void:
	if _game != null:
		_game.queue_free()
		_game = null
	_show_menu.call_deferred(reason)


func _on_solo(player_name: String) -> void:
	_new_game().start_solo(player_name)


func _on_host(player_name: String, port: int) -> void:
	var err := _new_game().start_host(player_name, port)
	if err != OK:
		_end_game("Could not host on port %d (%s)." % [port, error_string(err)])


func _on_join(player_name: String, address: String, port: int) -> void:
	var err := _new_game().start_join(player_name, address, port)
	if err != OK:
		_end_game("Could not connect to %s:%d (%s)." % [address, port, error_string(err)])
	else:
		_game.client.say("Connecting to %s:%d…" % [address, port])


func _auto_start(args: PackedStringArray) -> void:
	var opts := {}
	for a in args:
		var parts := a.trim_prefix("--").split("=", true, 1)
		opts[parts[0]] = parts[1] if parts.size() > 1 else ""
	var player_name: String = opts.get("name", "Adventurer")
	var port := int(opts.get("port", Net.DEFAULT_PORT))
	if opts.has("solo"):
		_on_solo(player_name)
	elif opts.has("host"):
		_on_host(player_name, port)
	elif opts.has("join"):
		_on_join(player_name, opts.join if opts.join != "" else "127.0.0.1", port)
