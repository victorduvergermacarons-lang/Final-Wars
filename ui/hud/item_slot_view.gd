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

const SIZE := Vector2(64, 64)
## Item names in a slot: up to two lines this size (was 6 letters at 11).
const NAME_SIZE := 14
## Slots drawn on the inventory page art: name size, and the rarity borders
## (Layer 5 of art/menu_book.aseprite: grey, green, blue, purple).
const PAGE_NAME_SIZE := 13
const RARITY_BORDERS: Array[Texture2D] = [
	preload("res://assets/ui/rarity/common.png"), preload("res://assets/ui/rarity/uncommon.png"),
	preload("res://assets/ui/rarity/rare.png"), preload("res://assets/ui/rarity/epic.png"),
]
## A bag slot with an item is tinted with its rarity's colour (the borders' colours),
## this much over the paper.
const RARITY_TINTS: Array[Color] = [Color("696a6a"), Color("629e39"), Color("639bff"), Color("76428a")]
const BAG_TINT := 0.3
## An equipment slot that the hovered or dragged item would go in glows this much.
const HIGHLIGHT_ALPHA := 0.22

var hud: Hud
var kind: Kind
var index: int
## Drawn on the inventory page art (no box of its own; see _draw_on_page).
var on_page := false
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
	if on_page:
		_draw_on_page()
		return
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, Color(0.08, 0.08, 0.1, 0.9))
	var it := item()
	if it == null:
		draw_rect(rect, LEARNING_COLOR.darkened(0.4) if kind == Kind.LEARNING else Color(0.35, 0.35, 0.4), false, 1.0)
		if kind == Kind.EQUIP:
			_lines(EquipSlot.NAMES[index], size.y * 0.5 - 2, NAME_SIZE, Color(0.6, 0.6, 0.65))
		elif kind == Kind.LEARNING:
			_lines("Learn", size.y * 0.5 + 5, NAME_SIZE, LEARNING_COLOR)
		return
	# Rarity colours are dark ink for the paper pages; inside the dark slot
	# they're lightened to show.
	var c := Rarity.color(it.rarity).lightened(0.45)
	draw_rect(rect.grow(-3), Color(c, 0.18))
	draw_rect(rect.grow(-1), c, false, 2.0)
	_lines(it.display_name, 19, NAME_SIZE, Color.WHITE)
	if kind == Kind.BAG:
		var n: int = hud.session.local_hero().bag.count_at(index)
		if n > 1:
			var count := str(n)
			_text(count, Vector2(size.x - 6 - _width(count, 16), size.y - 6), 16, Color(1, 1, 0.7))
	# Blue "L": the item being learned (the learning slot itself, or the worn weapon).
	if kind == Kind.LEARNING or it == hud.session.local_hero().active_learning_item():
		draw_rect(rect.grow(-1), LEARNING_COLOR, false, 2.0)
		_text("L", Vector2(size.x - 14, size.y - 10), 15, LEARNING_COLOR)
		var ability := it.tree_ability()
		if ability != null:
			var hero: Hero = hud.session.local_hero()
			var frac := float(hero.ap.get(ability.id, 0)) / maxf(ability.ap_to_master, 1.0)
			draw_rect(Rect2(2, size.y - 5, (size.x - 4) * frac, 3), LEARNING_COLOR)


## A slot drawn on the inventory page art (assets/ui/inventory_page.png): the
## frame and the empty-slot picture are in the art, so an empty slot draws
## nothing. With an item: an equipment slot covers its picture with paper and
## shows the item's full rarity border (the art's 28×29 frames, centred as
## drawn); a bag slot is tinted with the rarity's colour. Then the item's name in
## ink, until items have icons.
func _draw_on_page() -> void:
	var it := item()
	var px := BookView.REF_ART_SCALE # UI units per art pixel on the page
	var rect := Rect2(Vector2.ZERO, size)
	if it == null:
		_draw_highlight(rect, px)
		return
	if kind == Kind.BAG:
		# The frame line is on the edge of a bag frame.
		draw_rect(rect.grow(-px), UiPalette.PAPER.lerp(RARITY_TINTS[it.rarity], BAG_TINT))
	else:
		# Equipment frames draw their line 1 art pixel in (their corner dots stick out).
		draw_rect(rect.grow(-2.0 * px), UiPalette.PAPER)
		var border := RARITY_BORDERS[it.rarity]
		var border_size := Vector2(border.get_size()) * px
		draw_texture_rect(border, Rect2(((size - border_size) * 0.5).round(), border_size.round()), false)
	_draw_highlight(rect, px)
	var ink := UiPalette.INK
	_lines(it.display_name, size.y * 0.5 - 2, PAGE_NAME_SIZE, ink, false)
	if kind == Kind.BAG:
		var n: int = hud.session.local_hero().bag.count_at(index)
		if n > 1:
			var count := str(n)
			_text(count, Vector2(size.x - 2.0 * px - _width(count, 15), size.y - 2.0 * px), 15, ink, false)
	if kind == Kind.LEARNING or it == hud.session.local_hero().active_learning_item():
		var blue := Color(UiPalette.BLUE)
		_text("L", Vector2(size.x - 5.0 * px - 8, size.y - 5.0 * px), 15, blue, false) # inside the border
		var ability := it.tree_ability()
		if ability != null:
			var hero: Hero = hud.session.local_hero()
			var frac := float(hero.ap.get(ability.id, 0)) / maxf(ability.ap_to_master, 1.0)
			draw_rect(Rect2(5.0 * px, size.y - 4.0 * px - 3, (size.x - 10.0 * px) * frac, 3), blue)


## An equipment slot glows while the item under the mouse (or being dragged)
## would go in it.
func _draw_highlight(rect: Rect2, px: float) -> void:
	if kind != Kind.EQUIP or not fits(hud.dragged_item if hud.dragged_item != null else hud.hovered_item, index):
		return
	var inner := rect.grow(-2.0 * px)
	draw_rect(inner, Color(Color(UiPalette.GOLD), HIGHLIGHT_ALPHA))
	draw_rect(inner, Color(UiPalette.GOLD), false, px)


## Whether `it` would go in equipment slot `slot` (a two-handed weapon takes the
## off hand too).
static func fits(it: ItemDef, slot: int) -> bool:
	if it == null or not it.is_equippable():
		return false
	if it.slot == EquipSlot.Type.TWO_HAND and slot == EquipSlot.Id.OFF_HAND:
		return true
	return EquipSlot.slots_for(it.slot).has(slot)


## Hovering a bag item lights up where it would be worn; dragging any item keeps
## that up until it is dropped.
func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_ENTER and kind == Kind.BAG:
		hud.hovered_item = item()
	elif what == NOTIFICATION_MOUSE_EXIT and kind == Kind.BAG:
		hud.hovered_item = null
	elif what == NOTIFICATION_DRAG_END:
		hud.dragged_item = null


func _make_custom_tooltip(_for_text: String) -> Object:
	var it := item()
	if it == null:
		return null
	return ItemTooltip.label(it, hud.session.local_hero(), hud.session.rules(), kind != Kind.BAG, hud.session.now())


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
	hud.dragged_item = it # its equipment slots stay lit until the drop
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


## `t` on up to two lines from baseline `y`: words fill the first line, the rest
## goes on the second; each line is cut to fit the slot. On the page art the
## lines are centred and in ink (no outline).
func _lines(t: String, y: float, font_size: int, color: Color, outline: bool = true) -> void:
	var room := size.x - 8
	var words := t.split(" ", false)
	var first := ""
	var i := 0
	while i < words.size() and _width((first + " " + words[i]).strip_edges(), font_size) <= room:
		first = (first + " " + words[i]).strip_edges()
		i += 1
	if first == "" and not words.is_empty():
		first = _cut(words[0], room, font_size)
		i = 1
	var lines := [first]
	if i < words.size():
		lines.append(_cut(" ".join(words.slice(i)), room, font_size))
	for k in lines.size():
		var x := 4.0 if outline else roundf((size.x - _width(lines[k], font_size)) * 0.5)
		_text(lines[k], Vector2(x, y + k * (font_size + 2)), font_size, color, outline)


func _cut(t: String, room: float, font_size: int) -> String:
	while t.length() > 1 and _width(t, font_size) > room:
		t = t.left(t.length() - 1)
	return t


func _width(t: String, font_size: int) -> float:
	return _font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x


func _text(t: String, pos: Vector2, font_size: int, color: Color, outline: bool = true) -> void:
	if outline:
		draw_string_outline(_font, pos, t, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 3, Color.BLACK)
	draw_string(_font, pos, t, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
