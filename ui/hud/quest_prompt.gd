class_name QuestPrompt
extends PanelContainer
## Co-op: when a party member in your zone accepts a quest you could take, it is
## offered to you here (a paper note at the top of the screen): Join takes it
## without walking to its giver, Not now dismisses it. Several queue up.

const EXPIRE_SECONDS := 60.0

var hud: Hud
var _queue: Array = [] # [{"quest": StringName, "from": String, "at": float}]
var _text: RichTextLabel


func _init(p_hud: Hud) -> void:
	hud = p_hud
	custom_minimum_size = Vector2(420, 0)
	theme = UiPalette.paper_theme()
	add_theme_stylebox_override("panel", UiPalette.paper_panel(10))
	var box := VBoxContainer.new()
	add_child(box)
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.fit_content = true
	_text.custom_minimum_size = Vector2(400, 0)
	box.add_child(_text)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	row.add_child(_button("Join", _join))
	row.add_child(_button("Not now", _dismiss))
	visible = false


## Offers `quest_id`, which `from` (a party member's name) just accepted.
func offer(quest_id: StringName, from: String) -> void:
	for q in _queue:
		if q.quest == quest_id:
			return
	_queue.append({"quest": quest_id, "from": from, "at": _clock()})
	_show_first()


## The quest offered right now (&"" if none).
func current_quest() -> StringName:
	return _queue[0].quest if not _queue.is_empty() else &""


func _join() -> void:
	if _queue.is_empty():
		return
	hud.session.send_intent({"type": "accept_shared_quest", "quest": _queue[0].quest})
	_dismiss()


func _dismiss() -> void:
	if not _queue.is_empty():
		_queue.pop_front()
	_show_first()


func _show_first() -> void:
	var hero: Hero = hud.session.local_hero()
	# Drop offers that went stale or that you can't (or no longer need to) take.
	while not _queue.is_empty():
		var def: QuestDef = ContentDB.quests.get(_queue[0].quest)
		if def != null and hero != null and QuestLog.can_accept(hero, def) == "" \
				and _clock() - _queue[0].at < EXPIRE_SECONDS:
			break
		_queue.pop_front()
	visible = not _queue.is_empty()
	if not visible:
		return
	var first: Dictionary = _queue[0]
	var d: QuestDef = ContentDB.quests[first.quest]
	_text.text = "[b]%s[/b] took on a quest. Join them?\n\n%s" % [first.from, QuestText.summary_bbcode(hero, d)]


func _process(_delta: float) -> void:
	if visible:
		_show_first() # expire, or drop it once taken some other way


static func _clock() -> float:
	return Time.get_ticks_msec() / 1000.0


static func _button(text: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(on_press)
	return b
