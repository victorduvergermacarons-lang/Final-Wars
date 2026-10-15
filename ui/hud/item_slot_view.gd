class_name ItemSlotView
extends Control
## One bag or equipment slot in the inventory window, or the learning slot.
## Drag between slots to move/equip/unequip; drag a potion onto the action bar.
## Right-click: sell (while a shop is open), use a consumable, learn from a scroll,
## equip, or unequip. Shift+click a stack to split it. Ctrl+right-click a bag item
## to destroy it. The learning slot takes a scroll from the bag or the weapon in
## hand; right-click it (or drag it to the bag) to stop learning.

enum Kind { BAG, EQUIP, LEARNING }

const LEARNING_COLOR := Color(0.35, 0.7, 1.0)

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
	match kind:
		Kind.BAG:
			return hero.bag.item_at(index)
		Kind.LEARNING:
			return hero.learning_item
	return hero.equipped_in(index)


func _process(_delta: float) -> void:
	var it := item()
	var empty := ""
	if kind == Kind.EQUIP:
		empty = EquipSlot.NAMES[index]
	elif kind == Kind.LEARNING:
		empty = "Learning slot: drag a scroll from your bag (or right-click it), or your weapon, here. " \
				+ "Only this item earns AP toward its ability."
	tooltip_text = it.display_name if it != null else empty
	queue_redraw()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, Color(0.08, 0.08, 0.1, 0.9))
	var it := item()
	if it == null:
		draw_rect(rect, LEARNING_COLOR.darkened(0.4) if kind == Kind.LEARNING else Color(0.35, 0.35, 0.4), false, 1.0)
		if kind == Kind.EQUIP:
			_text(EquipSlot.NAMES[index].left(5), Vector2(4, size.y * 0.5 + 4), 10, Color(0.45, 0.45, 0.5))
		elif kind == Kind.LEARNING:
			_text("Learn", Vector2(4, size.y * 0.5 + 4), 10, LEARNING_COLOR.darkened(0.2))
		return
	var c := Rarity.color(it.rarity)
	draw_rect(rect.grow(-3), Color(c, 0.18))
	draw_rect(rect.grow(-1), c, false, 2.0)
	_text(it.display_name.left(6), Vector2(4, 18), 11, Color.WHITE)
	if kind == Kind.BAG:
		var n: int = hud.session.local_hero().bag.count_at(index)
		if n > 1:
			_text(str(n), Vector2(size.x - 16, size.y - 5), 12, Color(1, 1, 0.7))
	# Blue "L": the item being learned (the learning slot itself, or the worn weapon).
	if kind == Kind.LEARNING or it == hud.session.local_hero().active_learning_item():
		draw_rect(rect.grow(-1), LEARNING_COLOR, false, 2.0)
		_text("L", Vector2(size.x - 12, 14), 12, LEARNING_COLOR)
		var ability := it.tree_ability()
		if ability != null:
			var hero: Hero = hud.session.local_hero()
			var frac := float(hero.ap.get(ability.id, 0)) / maxf(ability.ap_to_master, 1.0)
			draw_rect(Rect2(2, size.y - 5, (size.x - 4) * frac, 3), LEARNING_COLOR)


func _make_custom_tooltip(_for_text: String) -> Object:
	var it := item()
	if it == null:
		return null
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.custom_minimum_size = Vector2(300, 0)
	label.text = ItemTooltip.text(it, hud.session.local_hero(), hud.session.rules(), kind != Kind.BAG)
	return label


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton) or not event.pressed:
		return
	var it := item()
	if it == null:
		return
	if event.button_index == MOUSE_BUTTON_RIGHT:
		if kind == Kind.LEARNING:
			hud.session.send_intent({"type": "stop_learning"})
		elif kind == Kind.EQUIP:
			hud.session.send_intent({"type": "unequip", "slot": index})
		elif event.ctrl_pressed:
			hud.inventory_window.confirm_destroy(index)
		elif hud.vendor_window.visible:
			hud.vendor_window.sell(index)
		elif it.use_ability != null:
			hud.session.send_intent({"type": "use_item", "bag_index": index})
		elif it.is_equippable():
			hud.session.send_intent({"type": "equip", "bag_index": index})
		elif it.is_scroll:
			hud.session.send_intent({"type": "learn", "bag_index": index})
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
	if typeof(data) != TYPE_DICTIONARY or not data.has("item_from"):
		return false
	if kind == Kind.LEARNING:
		return data.item_from != Kind.LEARNING
	return data.item_from != Kind.LEARNING or kind == Kind.BAG


func _drop_data(_at: Vector2, data: Variant) -> void:
	var from_bag: bool = data.item_from == Kind.BAG
	if kind == Kind.LEARNING:
		if from_bag:
			hud.session.send_intent({"type": "learn", "bag_index": data.index})
		else:
			hud.session.send_intent({"type": "learn", "slot": data.index})
	elif data.item_from == Kind.LEARNING:
		hud.session.send_intent({"type": "stop_learning"})
	elif from_bag and kind == Kind.BAG:
		hud.session.send_intent({"type": "move_item", "from": data.index, "to": index})
	elif from_bag and kind == Kind.EQUIP:
		hud.session.send_intent({"type": "equip", "bag_index": data.index, "slot": index})
	elif not from_bag and kind == Kind.BAG:
		hud.session.send_intent({"type": "unequip", "slot": data.index})


func _text(t: String, pos: Vector2, font_size: int, color: Color) -> void:
	draw_string_outline(_font, pos, t, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 3, Color.BLACK)
	draw_string(_font, pos, t, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
