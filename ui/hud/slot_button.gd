class_name SlotButton
extends Control
## One action bar slot: click to use, right-click to clear, drag to move,
## drop an ability from the spellbook onto it. Draws its own cooldown sweep.

const SIZE := Vector2(56, 56)
const TINTS := {
	Targeting.Usability.READY: Color(0.22, 0.24, 0.3),
	Targeting.Usability.COOLDOWN: Color(0.22, 0.24, 0.3),
	Targeting.Usability.NO_MANA: Color(0.15, 0.2, 0.55),
	Targeting.Usability.OUT_OF_RANGE: Color(0.5, 0.15, 0.15),
	Targeting.Usability.NO_TARGET: Color(0.5, 0.15, 0.15),
	Targeting.Usability.UNAVAILABLE: Color(0.15, 0.15, 0.15),
	Targeting.Usability.DEAD: Color(0.15, 0.15, 0.15),
}

var index := 0
var hud: Hud
var _font: Font


func _init(p_index: int, p_hud: Hud) -> void:
	index = p_index
	hud = p_hud
	custom_minimum_size = SIZE
	focus_mode = Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_STOP
	_font = ThemeDB.fallback_font


func _process(_delta: float) -> void:
	queue_redraw()
	var ability := _ability()
	tooltip_text = _tooltip(ability) if ability != null else "Empty slot. Drag an ability here from the Spellbook (P)."


func _ability() -> AbilityDef:
	var id := hud.client.action_bar.slots[index]
	if id == &"":
		return null
	var hero: Hero = hud.session.local_hero()
	var known := hero.find_ability(id) if hero != null else null
	return known if known != null else ContentDB.abilities.get(id)


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	var ability := _ability()
	var hero: Hero = hud.session.local_hero()
	var now: float = hud.session.now()
	var usable := Targeting.Usability.UNAVAILABLE
	if ability != null and hero != null:
		usable = Targeting.usability(hero, ability, hud.session.get_actor(hud.client.target_id),
				hud.session.grid(), hud.session.rules(), now, hud.session.actors())
	draw_rect(rect, TINTS[usable] if ability != null else Color(0.1, 0.1, 0.12, 0.8))
	var hovered := hud.bind_mode and hud.hovered_slot == index
	draw_rect(rect, Color(1, 0.85, 0.2) if hovered else Color(0.5, 0.5, 0.55), false, 2.0 if hovered else 1.0)
	if ability != null:
		var name := ability.display_name if ability.display_name != "" else String(ability.id)
		_text(name.left(8), Vector2(4, size.y - 8), 11, Color.WHITE)
		if hero != null:
			var cd := hero.cooldowns.ability_remaining(ability.id, now)
			var frac := hero.cooldowns.ability_fraction(ability.id, now)
			if ability.on_gcd:
				frac = maxf(frac, hero.cooldowns.gcd_fraction(now))
			if frac > 0.0:
				_draw_sweep(rect, frac)
			if cd > hero.cooldowns.gcd_remaining(now) and cd > 0.0:
				_text("%d" % ceili(cd) if cd >= 1.0 else "%.1f" % cd, Vector2(size.x * 0.5 - 8, size.y * 0.5 + 6), 16, Color(1, 1, 0.6))
	_text(hud.client.action_bar.key_label(index), Vector2(size.x - 14, 13), 11, Color(0.85, 0.85, 0.9))


func _draw_sweep(rect: Rect2, fraction: float) -> void:
	var c := rect.get_center()
	var r := minf(rect.size.x, rect.size.y) * 0.5
	var pts := PackedVector2Array([c])
	var steps := 24
	for i in steps + 1:
		var ang := -PI * 0.5 + TAU * fraction * i / steps
		pts.append(c + Vector2(cos(ang), sin(ang)) * r)
	draw_colored_polygon(pts, Color(0, 0, 0, 0.6))


func _text(t: String, pos: Vector2, font_size: int, color: Color) -> void:
	draw_string_outline(_font, pos, t, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 3, Color.BLACK)
	draw_string(_font, pos, t, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


static func _tooltip(a: AbilityDef) -> String:
	var lines: PackedStringArray = [a.display_name]
	if a.description != "":
		lines.append(a.description)
	var facts: PackedStringArray = []
	if a.mana_cost > 0:
		facts.append("%d mana" % a.mana_cost)
	match a.shape:
		AbilityDef.Shape.FRONT:
			facts.append("hits the tile in front" if a.max_range == 1 else "hits %d tiles ahead" % a.max_range)
		AbilityDef.Shape.LINE:
			facts.append("flies %d tiles ahead, stops at the first enemy" % a.max_range)
		_:
			if a.max_range > 0:
				facts.append("range %d" % a.max_range)
	if a.cooldown_seconds > 0:
		facts.append("%ss cooldown" % a.cooldown_seconds)
	if not facts.is_empty():
		lines.append(", ".join(facts))
	return "\n".join(lines)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and not hud.bind_mode:
		if event.button_index == MOUSE_BUTTON_LEFT:
			hud.input.use_slot(index)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			hud.client.action_bar.clear(index)
		accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_ENTER:
		hud.hovered_slot = index
	elif what == NOTIFICATION_MOUSE_EXIT and hud.hovered_slot == index:
		hud.hovered_slot = -1


func _get_drag_data(_at: Vector2) -> Variant:
	if hud.client.action_bar.slots[index] == &"":
		return null
	var preview := Label.new()
	preview.text = String(_ability().display_name)
	set_drag_preview(preview)
	return {"slot": index}


func _can_drop_data(_at: Vector2, data: Variant) -> bool:
	return typeof(data) == TYPE_DICTIONARY and (data.has("slot") or data.has("ability"))


func _drop_data(_at: Vector2, data: Variant) -> void:
	var bar := hud.client.action_bar
	if data.has("slot"):
		bar.swap(data.slot, index)
	else:
		bar.assign(index, data.ability)
