class_name ClientState
extends RefCounted
## Per-player client-side UI state shared by input, view and HUD.

var target_id: int = -1
var action_bar := ActionBarModel.new()
## Overhead marker per NPC def id ("!" quest available, "?" turn-in ready). Set by the quest UI.
var npc_markers := {}
## Short-lived error shown mid-screen ("Out of range"), with the time it appeared.
var error_text := ""
var error_at := -100.0
## Recent short messages for the player (rejections, level-ups…).
var messages: Array[String] = []


func say(text: String) -> void:
	messages.append(text)
	if messages.size() > 5:
		messages.pop_front()


func error(text: String) -> void:
	error_text = text
	error_at = Time.get_ticks_msec() / 1000.0
	say(text)
