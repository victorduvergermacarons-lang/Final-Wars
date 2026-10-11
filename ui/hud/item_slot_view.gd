class_name ItemSlotView
extends Control
## One bag or equipment slot in the inventory window.
## Drag between slots to move/equip/unequip. Right-click: equip from the bag or
## unequip. Shift+click a stack to split it. Ctrl+right-click a bag item to destroy it.

enum Kind { BAG, EQUIP }

const SIZE := Vector2(48, 48)

var hud: Hud
var kind: Kind
var index: int
var _font: Font


func _init(p_hud: Hud, p_kind: Kind, p_index: int) -> void:
	hud = p_hud
	kind = p_kind
	index = p_index
	custom_minimum_size = SIZE
	focus_mode = Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_STOP
	_font = ThemeDB.fallback_font


func item() -> ItemDef:
	var hero: Hero = hud.session.local_hero()
	if hero == null:
		return null
	return hero.bag.item_at(index) if kind == Kind.BAG else hero.equipped_in(index)


func _process(_delta: float) -> void:
	var it := item()
	tooltip_text = it.display_name if it != null else (EquipSlot.NAMES[index] if kind == Kind.EQUIP else "")
	queue_redraw()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, Color(0.08, 0.08, 0.1, 0.9))
	var it := item()
	if it == null:
		draw_rect(rect, Color(0.35, 0.35, 0.4), false, 1.0)
		if kind == Kind.EQUIP:
			_text(EquipSlot.NAMES[index].left(5), Vector2(4, size.y * 0.5 + 4), 10, Color(0.45, 0.45, 0.5))
		return
	var c := Rarity.color(it.rarity)
	draw_rect(rect.grow(-3), Color(c, 0.18))
	draw_rect(rect.grow(-1), c, false, 2.0)
	_text(it.display_name.left(6), Vector2(4, 18), 11, Color.WHITE)
	if kind == Kind.BAG:
		var n: int = hud.session.local_hero().bag.count_at(index)
		if n > 1:
			_text(str(n), Vector2(size.x - 16, size.y - 5), 12, Color(1, 1, 0.7))


func _make_custom_tooltip(_for_text: String) -> Object:
	var it := item()
	if it == null:
		return null
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.custom_minimum_size = Vector2(300, 0)
	label.text = ItemTooltip.text(it, hud.session.local_hero(), hud.session.rules(), kind == Kind.EQUIP)
	return label


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton) or not event.pressed:
		return
	var it := item()
	if it == null:
		return
	if event.button_index == MOUSE_BUTTON_RIGHT:
		if kind == Kind.EQUIP:
			hud.session.send_intent({"type": "unequip", "slot": index})
		elif event.ctrl_pressed:
			hud.inventory_window.confirm_destroy(index)
		elif it.is_equippable():
			hud.session.send_intent({"type": "equip", "bag_index": index})
		accept_event()
	elif event.button_index == MOUSE_BUTTON_LEFT and event.shift_pressed and kind == Kind.BAG:
		var n: int = hud.session.local_hero().bag.count_at(index)
		if n > 1:
			hud.session.send_intent({"type": "split_item", "index": index, "count": n / 2})
		accept_event()


func _get_drag_data(_at: Vector2) -> Variant:
	var it := item()
	if it == null:
		return null
	var preview := Label.new()
	preview.text = it.display_name
	preview.add_theme_color_override("font_color", Rarity.color(it.rarity))
	set_drag_preview(preview)
	return {"item_from": kind, "index": index}


func _can_drop_data(_at: Vector2, data: Variant) -> bool:
	return typeof(data) == TYPE_DICTIONARY and data.has("item_from")


func _drop_data(_at: Vector2, data: Variant) -> void:
	var from_bag: bool = data.item_from == Kind.BAG
	if from_bag and kind == Kind.BAG:
		hud.session.send_intent({"type": "move_item", "from": data.index, "to": index})
	elif from_bag and kind == Kind.EQUIP:
		hud.session.send_intent({"type": "equip", "bag_index": data.index, "slot": index})
	elif not from_bag and kind == Kind.BAG:
		hud.session.send_intent({"type": "unequip", "slot": data.index})


func _text(t: String, pos: Vector2, font_size: int, color: Color) -> void:
	draw_string_outline(_font, pos, t, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 3, Color.BLACK)
	draw_string(_font, pos, t, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
