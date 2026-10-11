class_name ClientState
extends RefCounted
## Per-player client-side UI state shared by input, view and HUD.

var target_id: int = -1
## Recent short messages for the player (rejections, level-ups…).
var messages: Array[String] = []


func say(text: String) -> void:
	messages.append(text)
	if messages.size() > 5:
		messages.pop_front()
