class_name QuestLogWindow
extends BookSpread
## Quest log (L), across the menu book: your active quests on the left page; the
## selected one's text, objectives and rewards on the right, with an Abandon
## button.

var hud: Hud
var selected: StringName = &""
var _list: VBoxContainer
var _details: RichTextLabel
var _abandon: Button
var _signature := ""


func _init(p_hud: Hud) -> void:
	super()
	hud = p_hud
	left.add_child(BookSpread.title("Quest Log"))
	_list = VBoxContainer.new()
	left.add_child(_list)
	_details = RichTextLabel.new()
	_details.bbcode_enabled = true
	_details.fit_content = true
	right.add_child(_details)
	_abandon = Button.new()
	_abandon.text = "Abandon quest"
	_abandon.focus_mode = Control.FOCUS_NONE
	_abandon.pressed.connect(func():
		hud.session.send_intent({"type": "abandon_quest", "quest": selected})
		selected = &"")
	right.add_child(_abandon)


func _process(_delta: float) -> void:
	if not visible:
		return
	var hero: Hero = hud.session.local_hero()
	if hero == null:
		return
	var active := QuestText.active_quests(hero, ContentDB.quests)
	if selected == &"" or not active.any(func(d): return d.id == selected):
		selected = active[0].id if not active.is_empty() else &""
	var sig := "%s|%s" % [selected, JSON.stringify(hero.quest_state)]
	for def in active:
		sig += "|%d" % [int(QuestLog.is_complete(hero, def))]
	if sig == _signature:
		return
	_signature = sig
	for c in _list.get_children():
		c.queue_free()
	for def in active:
		var b := Button.new()
		var ready := QuestLog.status(hero, def) == QuestLog.Status.READY
		b.text = def.title + ("  (done)" if ready else "")
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.focus_mode = Control.FOCUS_NONE
		b.toggle_mode = true
		b.button_pressed = def.id == selected
		var id := def.id
		b.pressed.connect(func():
			selected = id
			_signature = "")
		_list.add_child(b)
	_abandon.visible = selected != &""
	if selected == &"":
		_details.text = "[color=%s]No quests. Look for [b]![/b] over people in town.[/color]" % QuestText.GREY
		return
	var def: QuestDef = ContentDB.quests[selected]
	_details.text = "[b]%s[/b]\n%s\n\n%s\n\nHand in to: %s\n%s" % [def.title, def.offer_text,
			QuestText.objectives_bbcode(hero, def), QuestText.npc_name(def.turn_in_npc()),
			QuestText.rewards_bbcode(def)]
