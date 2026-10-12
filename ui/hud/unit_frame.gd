class_name UnitFrame
extends Control
## Name, level, HP and Mana (and optionally XP) for one actor. Click to target it.

var hud: Hud
## Returns the Actor to show, or null to hide the frame.
var source: Callable
var show_xp := false
var _font: Font


func _init(p_hud: Hud, p_source: Callable, width: float = 220.0, p_show_xp: bool = false) -> void:
	hud = p_hud
	source = p_source
	show_xp = p_show_xp
	custom_minimum_size = Vector2(width, 58 if p_show_xp else 50)
	focus_mode = Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_STOP
	_font = ThemeDB.fallback_font


func _process(_delta: float) -> void:
	var a: Actor = source.call()
	visible = a != null
	queue_redraw()


func _draw() -> void:
	var a: Actor = source.call()
	if a == null:
		return
	var now: float = hud.session.now()
	var stats := a.current_stats(now)
	var targeted := hud.client.target_id == a.id
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.05, 0.08, 0.8))
	draw_rect(Rect2(Vector2.ZERO, size), Color(1, 0.85, 0.2) if targeted else Color(0.4, 0.4, 0.45), false, 1.0)
	var title := a.display_name
	if a is Hero:
		title += "  Lv %d" % (a as Hero).level
	elif a is Enemy:
		title += "  Lv %d" % (a as Enemy).def.level
		if (a as Enemy).def.elite:
			title += "  Elite"
	if not a.alive:
		title += "  (dead)"
	elif a.in_combat(now):
		title += "  ⚔"
	_text(title, Vector2(6, 14), 13, Color(1, 0.6, 0.6) if a.team == Actor.Team.ENEMIES else Color.WHITE)
	var w := size.x - 12
	_bar(Rect2(6, 20, w, 12), a.hp, stats.hp, Color(0.2, 0.75, 0.3))
	if stats.mana > 0:
		_bar(Rect2(6, 34, w, 8), a.mana, stats.mana, Color(0.25, 0.45, 0.95))
	var effects: PackedStringArray = []
	for b in a.buffs.summary(now):
		var def: BuffDef = ContentDB.buffs.get(StringName(b[0]))
		effects.append(def.display_name if def != null and def.display_name != "" else String(b[0]))
	if not effects.is_empty():
		_text(" · ".join(effects), Vector2(size.x * 0.45, 14), 10, Color(0.75, 0.85, 1))
	if show_xp and a is Hero:
		var h := a as Hero
		_bar(Rect2(6, 46, w, 6), h.xp, Leveling.xp_to_next(h.level, hud.session.rules()), Color(0.75, 0.5, 0.95), false)


func _bar(r: Rect2, value: float, max_value: float, color: Color, label: bool = true) -> void:
	draw_rect(r, Color(0, 0, 0, 0.7))
	var f := clampf(value / maxf(max_value, 1.0), 0.0, 1.0)
	draw_rect(Rect2(r.position, Vector2(r.size.x * f, r.size.y)), color)
	if label and r.size.y >= 10:
		_text("%d / %d" % [value, max_value], r.position + Vector2(4, r.size.y - 2), 10, Color.WHITE)


func _text(t: String, pos: Vector2, font_size: int, color: Color) -> void:
	draw_string_outline(_font, pos, t, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 3, Color.BLACK)
	draw_string(_font, pos, t, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var a: Actor = source.call()
		if a != null:
			hud.client.target_id = a.id
		accept_event()
