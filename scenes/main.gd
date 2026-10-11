extends Node2D
## Entry scene. Starts a solo game until the host/join menu exists (step 9).


func _ready() -> void:
	$Title.queue_free()
	var game := Game.new()
	game.name = "Game"
	add_child(game)
	game.start_solo()
