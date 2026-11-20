class_name TradeWindow
extends PanelContainer
## The trade with another player (Trades, sent in snapshots), a paper sheet at the
## centre. While editing: "You give" (your items and gold, each removable, and your
## tradeable bag stacks to add) beside "You get" (theirs), each side marked once its
## owner has clicked Offer; Offer and Cancel. Once both have offered: the contract,
## exactly what each gives and gets, with Accept and Decline.

var hud: Hud
var _title: Label
var _edit: HBoxContainer
var _give: VBoxContainer
var _get: VBoxContainer
var _bag: VBoxContainer
var _gold: SpinBox
var _offer: Button
var _contract: VBoxContainer
var _contract_text: RichTextLabel
var _contract_status: Label
var _accept: Button
var _shown := "" # what is drawn, to rebuild only on change


func _init(p_hud: Hud) -> void:
	hud = p_hud
	custom_minimum_size = Vector2(720, 0)
	theme = UiPalette.paper_theme()
	add_theme_stylebox_override("panel", UiPalette.paper_panel(12))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	add_child(box)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 22)
	box.add_child(_title)
	# Editing: two panels and your bag.
	_edit = HBoxContainer.new()
	_edit.add_theme_constant_override("separation", 16)
	box.add_child(_edit)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_edit.add_child(left)
	_give = VBoxContainer.new()
	left.add_child(_give)
	var gold_row := HBoxContainer.new()
	left.add_child(gold_row)
	var gl := Label.new()
	gl.text = "Gold:"
	gold_row.add_child(gl)
	_gold = SpinBox.new()
	_gold.max_value = CharacterData.MAX_GOLD
	gold_row.add_child(_gold)
	var set_gold := Button.new()
	set_gold.text = "Set"
	set_gold.pressed.connect(func(): hud.session.send_intent({"type": "trade_gold", "amount": int(_gold.value)}))
	gold_row.add_child(set_gold)
	var bag_title := Label.new()
	bag_title.text = "Add from your bag:"
	left.add_child(bag_title)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 160)
	left.add_child(scroll)
	_bag = VBoxContainer.new()
	_bag.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_bag)
	_get = VBoxContainer.new()
	_get.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_edit.add_child(_get)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	_offer = _button(row, "Offer", func(): hud.session.send_intent({"type": "trade_offer"}))
	_button(row, "Cancel", cancel)
	# The contract.
	_contract = VBoxContainer.new()
	box.add_child(_contract)
	_contract_text = RichTextLabel.new()
	_contract_text.bbcode_enabled = true
	_contract_text.fit_content = true
	_contract_text.custom_minimum_size = Vector2(680, 0)
	_contract.add_child(_contract_text)
	_contract_status = Label.new()
	_contract_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_contract.add_child(_contract_status)
	var crow := HBoxContainer.new()
	crow.alignment = BoxContainer.ALIGNMENT_CENTER
	crow.add_theme_constant_override("separation", 12)
	_contract.add_child(crow)
	_accept = _button(crow, "Accept", func(): hud.session.send_intent({"type": "trade_accept"}))
	_button(crow, "Decline", cancel)
	visible = false


func _button(parent: Control, text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.name = text
	b.custom_minimum_size = Vector2(130, 0)
	b.pressed.connect(action)
	parent.add_child(b)
	return b


func cancel() -> void:
	hud.session.send_intent({"type": "trade_cancel"})


## The trade as this player sees it ({} = none).
func trade() -> Dictionary:
	return hud.session.social().get("trade", {})


func _process(_delta: float) -> void:
	var t := trade()
	visible = not t.is_empty()
	if not visible:
		_shown = ""
		return
	var hero: Hero = hud.session.local_hero()
	var key := str(t) + str(hero.bag.to_array()) + str(hero.gold)
	if key == _shown:
		return
	_shown = key
	var contract: bool = t.stage == "contract"
	_edit.visible = not contract
	_offer.get_parent().visible = not contract
	_contract.visible = contract
	if contract:
		_title.text = "Trade contract with %s" % t.with_name
		_contract_text.text = contract_text(t)
		_accept.disabled = t.mine.accepted
		_contract_status.text = "Waiting for %s to accept." % t.with_name if t.mine.accepted \
				else ("%s has accepted." % t.with_name if t.theirs.accepted else "")
		return
	_title.text = "Trade with %s" % t.with_name
	_fill_side(_give, "You give", t.mine, true)
	_fill_side(_get, "You get", t.theirs, false)
	_offer.disabled = t.mine.locked
	_offer.text = "Offered" if t.mine.locked else "Offer"
	for c in _bag.get_children():
		c.queue_free()
	for i in hero.bag.size():
		var item := hero.bag.item_at(i)
		if item == null or item.quest_item or not Binding.can_trade(hero.bag.bind_at(i), t.with_name, hud.session.now()):
			continue
		var line := HBoxContainer.new()
		var add := Button.new()
		add.text = "+"
		var index: int = i
		var n := hero.bag.count_at(i)
		add.pressed.connect(func(): hud.session.send_intent({"type": "trade_add", "index": index, "count": n}))
		line.add_child(add)
		line.add_child(_label(item, " x%d" % n if n > 1 else ""))
		_bag.add_child(line)


func _fill_side(box: VBoxContainer, title: String, side: Dictionary, mine: bool) -> void:
	for c in box.get_children():
		c.queue_free()
	var head := Label.new()
	head.text = "%s%s" % [title, "  (offered)" if side.locked else ""]
	head.add_theme_font_size_override("font_size", 18)
	box.add_child(head)
	for i in side.items.size():
		var e: Array = side.items[i]
		var item: ItemDef = ContentDB.items.get(StringName(str(e[0])))
		if item == null:
			continue
		var line := HBoxContainer.new()
		if mine:
			var rm := Button.new()
			rm.text = "x"
			var slot: int = i
			rm.pressed.connect(func(): hud.session.send_intent({"type": "trade_remove", "slot": slot}))
			line.add_child(rm)
		line.add_child(_label(item, " x%d" % e[1] if int(e[1]) > 1 else ""))
		box.add_child(line)
	if int(side.gold) > 0:
		var g := Label.new()
		g.text = "%d gold" % side.gold
		box.add_child(g)
	if side.items.is_empty() and int(side.gold) == 0:
		var none := Label.new()
		none.text = "(nothing yet)"
		box.add_child(none)


## An item's name with its tooltip, filling the rest of its row (a RichTextLabel
## with no width would wrap after every letter).
func _label(item: ItemDef, suffix: String) -> ItemLabel:
	var l := ItemLabel.new(hud, item, suffix)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	return l


## The contract: exactly what each player gives and gets.
static func contract_text(t: Dictionary) -> String:
	return "[b]You give %s:[/b] %s\n[b]You get from %s:[/b] %s" % [t.with_name, _list(t.mine), t.with_name,
			_list(t.theirs)]


static func _list(side: Dictionary) -> String:
	var parts: PackedStringArray = []
	for e in side.items:
		var item: ItemDef = ContentDB.items.get(StringName(str(e[0])))
		parts.append("%s%s" % [item.display_name if item else str(e[0]), " x%d" % e[1] if int(e[1]) > 1 else ""])
	if int(side.gold) > 0:
		parts.append("%d gold" % side.gold)
	return ", ".join(parts) if not parts.is_empty() else "nothing"
