class_name ActEndScreen
extends Control
## "End of Act I": shown when a hero hands in the quest that ends an act
## (QuestDef.ends_act). It dims the world and shows, on a paper sheet, the act's
## name, a line of story, and the party's records (Hero.records: level, enemies
## defeated, damage dealt, healing done, deaths, quests handed in). The button
## sends finish_act: the host takes the hero to the quest's return zone.

const TITLES := {1: "Act I: The Floor Guild"}
const LINES := {1: "Wells on the steppe, bread in Deepcut, medicine in Millbrook: every good deed was paid for in Sunstone. Now the Floor Guild's founder walks with the Ember Hand, and so do you."}
const COLUMNS := ["Hero", "Level", "Defeated", "Damage", "Healing", "Deaths", "Quests"]

var hud: Hud
var quest: StringName = &""
var act := 0
var _title: Label
var _story: Label
var _table: GridContainer
var _button: Button


func _init(p_hud: Hud) -> void:
	hud = p_hud
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP # the world waits behind it
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var sheet := PanelContainer.new()
	sheet.theme = UiPalette.paper_theme()
	sheet.add_theme_stylebox_override("panel", UiPalette.paper_panel(24))
	center.add_child(sheet)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	box.custom_minimum_size = Vector2(640, 0)
	sheet.add_child(box)
	var end := Label.new()
	end.text = "End of"
	end.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end.add_theme_font_size_override("font_size", 18)
	box.add_child(end)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 34)
	box.add_child(_title)
	_story = Label.new()
	_story.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_story.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_story.custom_minimum_size = Vector2(600, 0)
	box.add_child(_story)
	box.add_child(HSeparator.new())
	_table = GridContainer.new()
	_table.columns = COLUMNS.size()
	_table.add_theme_constant_override("h_separation", 22)
	_table.add_theme_constant_override("v_separation", 6)
	var middle := CenterContainer.new()
	middle.add_child(_table)
	box.add_child(middle)
	box.add_child(HSeparator.new())
	_button = Button.new()
	_button.text = "Return to the Crossing"
	_button.focus_mode = Control.FOCUS_NONE
	_button.pressed.connect(_finish)
	var row := CenterContainer.new()
	row.add_child(_button)
	box.add_child(row)
	visible = false


## Opens for `event` (an "act_complete" event: act, quest, party records).
func open(event: Dictionary) -> void:
	act = int(event.get("act", 1))
	quest = StringName(event.get("quest", ""))
	_title.text = TITLES.get(act, "Act %d" % act)
	_story.text = LINES.get(act, "")
	var def: QuestDef = ContentDB.quests.get(quest)
	var back: ZoneDef = ContentDB.zones.get(def.return_zone) if def != null else null
	_button.text = "Return to %s" % back.display_name if back != null else "Continue"
	for c in _table.get_children():
		c.queue_free()
	for col in COLUMNS:
		_table.add_child(_cell(col, true))
	for p in event.get("party", []):
		for v in [p.name, p.level, p.kills, p.damage, p.healing, p.deaths, p.quests]:
			_table.add_child(_cell(str(v), false))
	visible = true


## The table's text, one row per hero (for tests).
func rows() -> Array:
	var out := []
	var cells := _table.get_children().filter(func(c): return not c.is_queued_for_deletion())
	for i in range(0, cells.size(), COLUMNS.size()):
		out.append(cells.slice(i, i + COLUMNS.size()).map(func(c): return c.text))
	return out


func _finish() -> void:
	visible = false
	hud.session.send_intent({"type": "finish_act", "quest": quest})


static func _cell(text: String, head: bool) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 18 if head else 20)
	if head:
		l.add_theme_color_override("font_color", UiPalette.INK_SOFT)
	return l
