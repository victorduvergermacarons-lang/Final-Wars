class_name VendorWindow
extends PanelContainer
## A vendor's goods. Buy with the buttons; while this is open, right-click an item
## in your bag to sell it (25% of its price). Closes when the conversation ends.

var hud: Hud
var npc_id := -1
var _title: Label
var _gold: Label
var _list: VBoxContainer


func _init(p_hud: Hud) -> void:
	hud = p_hud
	custom_minimum_size = Vector2(320, 0)
	var box := VBoxContainer.new()
	add_child(box)
	_title = Label.new()
	_title.add_theme_color_override("font_color", Color(1, 0.9, 0.6))
	box.add_child(_title)
	var hint := Label.new()
	hint.text = "Right-click an item in your bag (B) to sell it."
	hint.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	box.add_child(hint)
	_gold = Label.new()
	_gold.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	box.add_child(_gold)
	# The goods scroll (Hilda sells two dozen things).
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(320, 340)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	visible = false


func open(npc: Npc) -> void:
	npc_id = npc.id
	_title.text = "%s — goods" % npc.display_name
	for c in _list.get_children():
		c.queue_free()
	for item in npc.def.sells:
		var row := HBoxContainer.new()
		var name := RichTextLabel.new()
		name.bbcode_enabled = true
		name.fit_content = true
		name.custom_minimum_size = Vector2(200, 0)
		name.text = "[color=#%s]%s[/color]  %d gold" % [Rarity.color(item.rarity).to_html(false), item.display_name, item.price]
		name.tooltip_text = item.description
		row.add_child(name)
		var buy := Button.new()
		buy.text = "Buy"
		buy.focus_mode = Control.FOCUS_NONE
		var id := item.id
		buy.pressed.connect(func(): buy_item(id))
		row.add_child(buy)
		_list.add_child(row)
	visible = true


func buy_item(item_id: StringName, count: int = 1) -> void:
	hud.session.send_intent({"type": "buy", "npc": npc_id, "item": item_id, "count": count})


func sell(bag_index: int) -> void:
	var hero: Hero = hud.session.local_hero()
	hud.session.send_intent({"type": "sell", "npc": npc_id, "bag_index": bag_index,
			"count": hero.bag.count_at(bag_index)})


func close() -> void:
	visible = false
	npc_id = -1


func _process(_delta: float) -> void:
	if not visible:
		return
	var hero: Hero = hud.session.local_hero()
	if hero != null:
		_gold.text = "Your gold: %d" % hero.gold
