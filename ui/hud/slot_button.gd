class_name SlotButton
extends Control
## One slot of the ability wheel: click to use, right-click to clear, drag to move
## (or off the wheel to clear), drop an ability from the spellbook onto it. Draws its
## own cooldown sweep and the button that fires it (keyboard or controller, whichever
## was used last).

const SIZE := Vector2(64, 64)
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
## What this slot held when a drag from it started (cleared when dropped off the bar).
var _dragged_entry: StringName = &""
var _dragging := false


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
	var item := _item()
	if item != null:
		tooltip_text = "%s\n%s" % [item.display_name, item.description]
	else:
		tooltip_text = _tooltip(ability) if ability != null else "Empty slot. Drag an ability from the Spellbook (P) or a potion from your bag."


## For item slots, the consumable (else null).
func _item() -> ItemDef:
	if not _kit().is_empty():
		return null
	var id := hud.client.action_bar.slots[index]
	return ContentDB.items.get(ActionBarModel.item_id_of(id)) if ActionBarModel.is_item_slot(id) else null


## The element kit's entry for this button ({} if the kit doesn't cover it).
func _kit() -> Dictionary:
	return hud.input.kit_entry(index) if hud.input != null else {}


## The kit ability a press would use now: the tap, the combo's next step, the charge.
func _kit_ability(e: Dictionary) -> AbilityDef:
	if e.has("combo"):
		return e.combo[0]
	return e.get("tap", e.get("charge", e.get("hold")))


func _ability() -> AbilityDef:
	var kit := _kit()
	if not kit.is_empty():
		return _kit_ability(kit)
	var id := hud.client.action_bar.slots[index]
	if id == &"":
		return null
	if ActionBarModel.is_item_slot(id):
		var item := _item()
		return item.use_ability if item != null else null
	var hero: Hero = hud.session.local_hero()
	var known := hero.find_ability(id) if hero != null else null
	return known if known != null else ContentDB.abilities.get(id)


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	var ability := _ability()
	var hero: Hero = hud.session.local_hero()
	var now: float = hud.session.now()
	var usable := Targeting.Usability.UNAVAILABLE
	var item := _item()
	var held := hero.bag.count_of(item) if item != null and hero != null else 0
	if item != null and hero != null:
		usable = Targeting.Usability.UNAVAILABLE if held == 0 else (
				Targeting.Usability.READY if hero.cooldowns.can_use(ability, now) else Targeting.Usability.COOLDOWN)
	elif ability != null and hero != null:
		usable = Targeting.usability(hero, ability, hud.session.get_actor(hud.client.target_id),
				hud.session.grid(), hud.session.rules(), now, hud.session.actors())
	draw_rect(rect, TINTS[usable] if ability != null else Color(0.1, 0.1, 0.12, 0.8))
	draw_rect(rect, Color(0.5, 0.5, 0.55), false, 1.0)
	if ability != null:
		var name := ability.display_name if ability.display_name != "" else String(ability.id)
		if item != null:
			name = item.display_name.trim_prefix("Minor ")
			_text(str(held), Vector2(size.x - 14, size.y - 20), 12, Color(1, 1, 0.7))
		_text(name.left(10), Vector2(4, size.y - 8), 11, Color.WHITE)
		if hero != null:
			var cd := hero.cooldowns.ability_remaining(ability.cooldown_key(), now)
			var frac := hero.cooldowns.ability_fraction(ability.cooldown_key(), now)
			if ability.on_gcd:
				frac = maxf(frac, hero.cooldowns.gcd_fraction(now))
			if frac > 0.0:
				_draw_sweep(rect, frac)
			if cd > hero.cooldowns.gcd_remaining(now) and cd > 0.0:
				_text("%d" % ceili(cd) if cd >= 1.0 else "%.1f" % cd, Vector2(size.x * 0.5 - 8, size.y * 0.5 + 6), 16, Color(1, 1, 0.6))
	var key := InputActions.hint(InputActions.slot_action(index))
	var w := _font.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	_text(key, Vector2(size.x - w - 4, 13), 11, Color(0.85, 0.85, 0.9))
	# The kit's second use of the button: hold (or a combo's or charge's note).
	var kit := _kit()
	var second := ""
	if kit.has("hold"):
		second = "hold: " + kit.hold.display_name
	elif kit.has("combo"):
		second = " > ".join(kit.combo.map(func(a): return a.display_name.get_slice(" ", 1).left(5)))
	elif kit.has("charge"):
		second = "hold to grow"
	if second != "":
		_text(second.left(16), Vector2(3, 25), 9, Color(0.75, 0.85, 1.0))
	# A held button fills a ring toward its hold (or its charge).
	var p: float = hud.input.hold_progress(index) if hud.input != null else -1.0
	if p >= 0.0:
		draw_arc(rect.get_center(), size.x * 0.46, -PI / 2.0, -PI / 2.0 + TAU * p, 32, Color(1, 0.85, 0.3), 3.0)


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
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			hud.input.use_slot(index)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			hud.client.action_bar.clear(index)
		accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END and _dragging:
		_dragging = false
		if not get_viewport().gui_is_drag_successful():
			drop_off_bar()


## A drag from this slot ended outside any slot: the ability leaves the bar.
func drop_off_bar() -> void:
	var bar := hud.client.action_bar
	if bar.slots[index] == _dragged_entry and _dragged_entry != &"":
		bar.clear(index)
	_dragged_entry = &""


func _get_drag_data(_at: Vector2) -> Variant:
	if hud.client.action_bar.slots[index] == &"":
		return null
	var preview := Label.new()
	preview.text = _item().display_name if _item() != null else String(_ability().display_name)
	set_drag_preview(preview)
	_dragging = true
	_dragged_entry = hud.client.action_bar.slots[index]
	return {"slot": index}


func _can_drop_data(_at: Vector2, data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY:
		return false
	if not _kit().is_empty():
		return false # the element kit decides this button
	if data.has("item_from"):
		return _dragged_consumable(data) != null
	return data.has("slot") or data.has("ability")


## A usable item dragged from the bag, or null.
func _dragged_consumable(data: Dictionary) -> ItemDef:
	if data.get("item_from") != ItemSlotView.Kind.BAG:
		return null
	var item: ItemDef = hud.session.local_hero().bag.item_at(data.index)
	return item if item != null and item.use_ability != null else null


func _drop_data(_at: Vector2, data: Variant) -> void:
	var bar := hud.client.action_bar
	if data.has("item_from"):
		bar.assign(index, ActionBarModel.item_entry(_dragged_consumable(data).id))
	elif data.has("slot"):
		bar.swap(data.slot, index)
	else:
		bar.assign(index, data.ability)
