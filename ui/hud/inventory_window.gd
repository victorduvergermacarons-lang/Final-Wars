class_name InventoryWindow
extends BookSpread
## Inventory (B), drawn by hand on the menu book (Layer 4 of
## art/menu_book.aseprite: assets/ui/inventory_page.png): the learning slot and
## the nine equipment slots on the left page, the bag on the right. Each slot
## sits on its frame in the art, in art pixels (measured on the art); the learning
## text and your gold go under the bag.

const BAG_COLUMNS := 5
const PAGE_ART := preload("res://assets/ui/inventory_page.png")
## Frames in the art (book pixels): equipment slots are 34×35, bag slots 26×26.
const EQUIP_FRAME := Vector2(34, 35)
const LEARNING_AT := Vector2(93, 66) # the scroll
## EquipSlot index -> frame's top-left: hat, chest, trousers, boots, glove, sword,
## arrow (off hand), and the two accessories (the band, the ring).
const EQUIP_AT := {
	0: Vector2(129, 66), 1: Vector2(129, 103), 2: Vector2(129, 140), 3: Vector2(130, 178),
	4: Vector2(93, 103), 5: Vector2(165, 66), 6: Vector2(165, 103), 7: Vector2(93, 140),
	8: Vector2(165, 140),
}
const BAG_FRAME := Vector2(26, 26)
const BAG_AT := Vector2(261, 65)
const BAG_STEP := 29.0
## Under the bag on the right page: what is being learned, and gold.
const INFO_AT := Rect2(261, 182, 142, 38)

var hud: Hud
var _confirm: ConfirmationDialog
var _pending_destroy := -1
var _gold: Label
var _learning: Label
var _info: VBoxContainer
## [ItemSlotView, art rect] for every slot on the page.
var _placed: Array = []


func _init(p_hud: Hud) -> void:
	super()
	hud = p_hud
	page_art = PAGE_ART
	_place_slot(ItemSlotView.new(hud, ItemSlotView.Kind.LEARNING, 0), Rect2(LEARNING_AT, EQUIP_FRAME))
	for slot in EQUIP_AT:
		_place_slot(ItemSlotView.new(hud, ItemSlotView.Kind.EQUIP, slot), Rect2(EQUIP_AT[slot], EQUIP_FRAME))
	for i in Bag.DEFAULT_SIZE:
		var at := BAG_AT + Vector2(i % BAG_COLUMNS, i / BAG_COLUMNS) * BAG_STEP
		_place_slot(ItemSlotView.new(hud, ItemSlotView.Kind.BAG, i), Rect2(at, BAG_FRAME))
	_info = VBoxContainer.new()
	_info.add_theme_constant_override("separation", 0)
	add_child(_info)
	_learning = Label.new()
	_learning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_learning.add_theme_font_size_override("font_size", 16)
	_learning.add_theme_color_override("font_color", Color(UiPalette.BLUE))
	_info.add_child(_learning)
	_gold = Label.new()
	_gold.add_theme_font_size_override("font_size", 16)
	_gold.add_theme_color_override("font_color", Color(UiPalette.GOLD))
	_info.add_child(_gold)
	_confirm = ConfirmationDialog.new()
	_confirm.confirmed.connect(_on_destroy_confirmed)
	add_child(_confirm)


func _place_slot(view: ItemSlotView, art_rect: Rect2) -> void:
	view.on_page = true
	add_child(view)
	_placed.append([view, art_rect])


## Slots go on their frames in the art; this control is the spread, laid out at
## the book's 1080p size (BookView.REF_ART_SCALE units per art pixel).
func lay_out(left_rect: Rect2, right_rect: Rect2) -> void:
	super.lay_out(left_rect, right_rect)
	for p in _placed:
		_put(p[0], p[1])
	_put(_info, INFO_AT)


static func _put(c: Control, art_rect: Rect2) -> void:
	var s := BookView.REF_ART_SCALE
	c.custom_minimum_size = (art_rect.size * s).round()
	c.position = ((art_rect.position - BookView.LEFT_PAGE.position) * s).round()
	c.size = c.custom_minimum_size


func confirm_destroy(index: int) -> void:
	var item: ItemDef = hud.session.local_hero().bag.item_at(index)
	if item == null:
		return
	_pending_destroy = index
	_confirm.dialog_text = "Destroy %s? This can't be undone." % item.display_name
	_confirm.popup_centered()


func _on_destroy_confirmed() -> void:
	if _pending_destroy >= 0:
		hud.session.send_intent({"type": "destroy_item", "index": _pending_destroy})
	_pending_destroy = -1


func _process(_delta: float) -> void:
	var hero: Hero = hud.session.local_hero()
	if visible and hero != null:
		_gold.text = "Gold: %d" % hero.gold
		_learning.text = LearningRow.text_for(hero).replace("\n", " ")
