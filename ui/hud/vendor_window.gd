class_name VendorWindow
extends PanelContainer
## A vendor's shop: a paper sheet of its own, apart from the menu book, so it can
## stay open next to your inventory. Buy with the buttons; right-click an item in
## your bag to sell it (25% of its price). Drag the sheet by its title to move
## it. Closes when the conversation ends, or with its Close button.

const WIDTH := 400.0
## Where it first opens, and how much of it stays on screen when dragged.
const START := Vector2(16, 120)
const KEEP_VISIBLE := Vector2(120, 40)
## The goods list's height: at most this, less if the sheet would reach the
## action bar (BOTTOM_ROOM at the bottom of the screen) from where it opens.
const MAX_LIST_H := 420.0
const MIN_LIST_H := 160.0
const BOTTOM_ROOM := 110.0
## The sheet's height besides the list: title, gold, hint, margins.
const AROUND_LIST_H := 120.0

var hud: Hud
var npc_id := -1
var _title: Label
var _gold: Label
var _list: VBoxContainer
var _scroll: ScrollContainer
var _dragging := false


func _init(p_hud: Hud) -> void:
	hud = p_hud
	theme = UiPalette.paper_theme()
	add_theme_stylebox_override("panel", UiPalette.paper_panel(12))
	custom_minimum_size = Vector2(WIDTH, 0)
	position = START
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", BookSpread.SEPARATION)
	add_child(box)
	# The title row is the handle: drag it to move the sheet.
	var header := HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_STOP
	header.mouse_default_cursor_shape = Control.CURSOR_MOVE
	header.gui_input.connect(_on_header_input)
	box.add_child(header)
	_title = BookSpread.title("")
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title)
	var close_button := Button.new()
	close_button.text = "Close"
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	close_button.pressed.connect(close)
	header.add_child(close_button)
	_gold = Label.new()
	_gold.add_theme_color_override("font_color", Color(UiPalette.GOLD))
	box.add_child(_gold)
	# The goods scroll (Hilda sells two dozen things); open() fits it to the screen.
	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(0, MAX_LIST_H)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_list)
	box.add_child(BookSpread.note("Right-click an item in your bag (B) to sell it."))
	visible = false


func open(npc: Npc) -> void:
	npc_id = npc.id
	_title.text = "%s's goods" % npc.display_name
	for c in _list.get_children():
		c.queue_free()
	for item in npc.def.sells:
		var row := HBoxContainer.new()
		var name := RichTextLabel.new()
		name.bbcode_enabled = true
		name.fit_content = true
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
	# Fit the list between where the sheet sits and the action bar.
	var screen_h := get_viewport_rect().size.y if is_inside_tree() else 720.0
	_scroll.custom_minimum_size.y = clampf(screen_h - BOTTOM_ROOM - position.y - AROUND_LIST_H, MIN_LIST_H, MAX_LIST_H)
	visible = true
	# Shrink to the new content once it has been laid out.
	reset_size.call_deferred()


func buy_item(item_id: StringName, count: int = 1) -> void:
	hud.session.send_intent({"type": "buy", "npc": npc_id, "item": item_id, "count": count})


func sell(bag_index: int) -> void:
	var hero: Hero = hud.session.local_hero()
	hud.session.send_intent({"type": "sell", "npc": npc_id, "bag_index": bag_index,
			"count": hero.bag.count_at(bag_index)})


func close() -> void:
	visible = false
	npc_id = -1


func _on_header_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
		accept_event()
	elif event is InputEventMouseMotion and _dragging:
		var screen := get_viewport_rect().size
		position = (position + event.relative).clamp(Vector2(KEEP_VISIBLE.x - size.x, 0),
				screen - KEEP_VISIBLE).round()
		accept_event()


func _process(_delta: float) -> void:
	if not visible:
		return
	var hero: Hero = hud.session.local_hero()
	if hero != null:
		_gold.text = "Your gold: %d" % hero.gold
