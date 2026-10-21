class_name LootWindow
extends BookSpread
## Loot that didn't fit in your bag waits here for 60 s, across the menu book:
## the loot on the left page, your bag on the right. Make room, then Take.

var hud: Hud
var _list: VBoxContainer
var _shown := ""


func _init(p_hud: Hud) -> void:
	super()
	hud = p_hud
	var title := BookSpread.title("Loot")
	title.add_theme_color_override("font_color", Color(UiPalette.GOLD))
	left.add_child(title)
	set_footnote("Your bag was full. Make room, then Take.")
	_list = VBoxContainer.new()
	left.add_child(_list)
	right.add_child(BookSpread.title("Your bag"))
	right.add_child(BookSpread.bag_grid(hud))
	visible = false


func _process(_delta: float) -> void:
	var loot: Array = hud.session.pending_loot()
	var key := str(loot.map(func(l): return [l.id, l.items]))
	if loot.is_empty():
		visible = false
	elif key != _shown:
		visible = true # new loot opens it; closed, it stays closed until more comes
	if key == _shown:
		_update_timers(loot)
		return
	_shown = key
	for c in _list.get_children():
		c.queue_free()
	for l in loot:
		var row := HBoxContainer.new()
		var text := RichTextLabel.new()
		text.bbcode_enabled = true
		text.fit_content = true
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.text = ", ".join(l.items.map(func(pair): return _item_text(pair)))
		row.add_child(text)
		var timer := Label.new()
		timer.name = "Timer"
		row.add_child(timer)
		var take := Button.new()
		take.text = "Take"
		take.focus_mode = Control.FOCUS_NONE
		var id: int = l.id
		take.pressed.connect(func(): hud.session.send_intent({"type": "take_loot", "loot": id}))
		row.add_child(take)
		row.set_meta("loot_id", l.id)
		_list.add_child(row)
	_update_timers(loot)


func _update_timers(loot: Array) -> void:
	for row in _list.get_children():
		for l in loot:
			if l.id == row.get_meta("loot_id", -1):
				(row.get_node("Timer") as Label).text = "%ds" % maxi(ceili(l.expires - hud.session.now()), 0)


static func _item_text(pair: Array) -> String:
	var item: ItemDef = ContentDB.items.get(StringName(str(pair[0])))
	if item == null:
		return str(pair[0])
	var n: int = pair[1]
	return "[color=#%s]%s[/color]%s" % [Rarity.color(item.rarity).to_html(false), item.display_name,
			" ×%d" % n if n > 1 else ""]
