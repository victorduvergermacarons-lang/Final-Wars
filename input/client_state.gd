class_name ClientState
extends RefCounted
## Per-player client-side UI state shared by input, view and HUD.

var target_id: int = -1
## While aiming a skillshot or ground ability (PlayerInput): {"ability", "tiles",
## "valid", "point"}; empty otherwise. WorldView highlights the tiles.
var aim := {}
var action_bar := ActionBarModel.new()
## The local right-clicks on the current timing bar, before the host answers:
## {"start": the bar's start time, "next": the next input to play, "presses":
## [{"index": the input, "at": seconds into the bar, "holding": a hold started,
## "release": seconds into the bar when let go}…]}. TimingBarView shows them at once.
var timing_press := {}
## Overhead marker per NPC def id ("!" quest available, "?" turn-in ready). Set by the quest UI.
var npc_markers := {}
## Speech bubbles over actors (what someone else's conversation says, for the rest
## of the party): actor id -> {"text", "until"} (client clock, seconds).
var bubbles := {}
const BUBBLE_SECONDS := 4.0
const BUBBLE_CHARS := 70
## Short-lived error shown mid-screen ("Out of range"), with the time it appeared.
var error_text := ""
var error_at := -100.0
## Recent short messages for the player (rejections, level-ups…).
var messages: Array[String] = []
## Every message this session, oldest first (the Escape menu's Log), up to
## HISTORY_SIZE.
var history: Array[String] = []
const HISTORY_SIZE := 300


func say(text: String) -> void:
	messages.append(text)
	if messages.size() > 5:
		messages.pop_front()
	history.append(text)
	if history.size() > HISTORY_SIZE:
		history.pop_front()


## Shows `text` in a bubble over actor `actor_id` for a few seconds (shortened).
func bubble(actor_id: int, text: String) -> void:
	var t := text.strip_edges()
	if t.length() > BUBBLE_CHARS:
		t = t.substr(0, BUBBLE_CHARS - 1).strip_edges() + "…"
	bubbles[actor_id] = {"text": t, "until": Time.get_ticks_msec() / 1000.0 + BUBBLE_SECONDS}


## Live bubbles (expired ones dropped).
func live_bubbles() -> Dictionary:
	var now := Time.get_ticks_msec() / 1000.0
	for id in bubbles.keys():
		if bubbles[id].until < now:
			bubbles.erase(id)
	return bubbles


func error(text: String) -> void:
	error_text = text
	error_at = Time.get_ticks_msec() / 1000.0
	say(text)
