class_name InventoryWindow
extends BookSpread
## Inventory (B), across the menu book: what you wear on the left page (the nine
## equipment positions and the learning slot), your bag on the right.

const BAG_COLUMNS := 5

var hud: Hud
var _confirm: ConfirmationDialog
var _pending_destroy := -1
var _gold: Label


func _init(p_hud: Hud) -> void:
	super()
	hud = p_hud
	left.add_child(BookSpread.title("Equipment"))
	# Worn items in the middle of the page.
	var equip := GridContainer.new()
	equip.columns = 3
	equip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	equip.add_theme_constant_override("h_separation", 6)
	equip.add_theme_constant_override("v_separation", 6)
	for slot in EquipSlot.COUNT:
		equip.add_child(ItemSlotView.new(hud, ItemSlotView.Kind.EQUIP, slot))
	left.add_child(equip)
	var learning := LearningRow.new(hud)
	learning.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	left.add_child(learning)
	_gold = Label.new()
	_gold.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gold.add_theme_color_override("font_color", Color(UiPalette.GOLD))
	left.add_child(_gold)
	set_footnote("Drag to move or equip · right-click to equip or take off · "
			+ "shift+click to split a stack · ctrl+right-click to destroy")

	right.add_child(BookSpread.title("Bag"))
	right.add_child(BookSpread.bag_grid(hud, BAG_COLUMNS))
	_confirm = ConfirmationDialog.new()
	_confirm.confirmed.connect(_on_destroy_confirmed)
	add_child(_confirm)


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
