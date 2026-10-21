class_name InventoryWindow
extends PanelContainer
## Inventory (B): the nine equipment positions next to the bag grid.

const BAG_COLUMNS := 5

var hud: Hud
var _confirm: ConfirmationDialog
var _pending_destroy := -1
var _gold: Label


func _init(p_hud: Hud) -> void:
	hud = p_hud
	var box := VBoxContainer.new()
	add_child(box)
	var title := Label.new()
	title.text = "Inventory (B) — drag to move or equip · right-click equip/unequip · shift+click split · ctrl+right-click destroy"
	title.autowrap_mode = TextServer.AUTOWRAP_WORD
	title.custom_minimum_size = Vector2(420, 0)
	box.add_child(title)
	_gold = Label.new()
	_gold.add_theme_color_override("font_color", Color(UiPalette.GOLD))
	box.add_child(_gold)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	box.add_child(row)
	var left := VBoxContainer.new()
	row.add_child(left)
	var equip := GridContainer.new()
	equip.columns = 3
	for slot in EquipSlot.COUNT:
		equip.add_child(ItemSlotView.new(hud, ItemSlotView.Kind.EQUIP, slot))
	left.add_child(equip)
	left.add_child(LearningRow.new(hud))
	var bag := GridContainer.new()
	bag.columns = BAG_COLUMNS
	for i in Bag.DEFAULT_SIZE:
		bag.add_child(ItemSlotView.new(hud, ItemSlotView.Kind.BAG, i))
	row.add_child(bag)
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
