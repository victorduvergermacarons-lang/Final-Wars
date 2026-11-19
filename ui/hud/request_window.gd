class_name RequestWindow
extends PanelContainer
## A trade or duel request from another player, at the centre of the screen:
## "<name> wants to trade with you" with Accept / Decline and the seconds left
## (it declines itself after PartyPlayDef.request_seconds). One at a time.

var hud: Hud
var _text: Label
var _id := -1
## Requests already answered here (hidden before the host confirms).
var answered := {}


func _init(p_hud: Hud) -> void:
	hud = p_hud
	custom_minimum_size = Vector2(380, 0)
	theme = UiPalette.paper_theme()
	add_theme_stylebox_override("panel", UiPalette.paper_panel(10))
	var box := VBoxContainer.new()
	add_child(box)
	_text = Label.new()
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD
	box.add_child(_text)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	for c in [["Accept", true], ["Decline", false]]:
		var b := Button.new()
		b.text = c[0]
		b.name = c[0]
		b.custom_minimum_size = Vector2(120, 0)
		var yes: bool = c[1]
		b.pressed.connect(func(): answer(yes))
		row.add_child(b)
	visible = false


## The request showing (-1 = none; tests).
func showing() -> int:
	return _id if visible else -1


func answer(accept: bool) -> void:
	if _id < 0:
		return
	answered[_id] = true
	hud.session.send_intent({"type": "request_answer", "request": _id, "accept": accept})
	visible = false


func _process(_delta: float) -> void:
	var me: int = hud.session.local_hero_id
	var r := {}
	for q in hud.session.social().get("requests", []):
		if q.to == me and not answered.has(q.id):
			r = q
			break
	visible = not r.is_empty()
	if not visible:
		_id = -1
		return
	_id = r.id
	var left := maxf(float(r.expires) - hud.session.now(), 0.0)
	_text.text = "%s wants to %s you.\n(%d s)" % [r.from_name, "trade with" if r.kind == "trade" else "duel",
			ceili(left)]
