class_name BossLootSummary
extends PanelContainer
## After a boss falls: what every player received (gold, materials copied to all,
## each one's own drops; boss rolls add their winners when they are decided). A
## paper sheet at the top centre, gone after PartyPlayDef.boss_summary_seconds or
## when closed.

var hud: Hud
var _text: RichTextLabel
var _until := 0.0


func _init(p_hud: Hud) -> void:
	hud = p_hud
	custom_minimum_size = Vector2(460, 0)
	theme = UiPalette.paper_theme()
	add_theme_stylebox_override("panel", UiPalette.paper_panel(10))
	var box := VBoxContainer.new()
	add_child(box)
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.fit_content = true
	_text.custom_minimum_size = Vector2(440, 0)
	box.add_child(_text)
	var close := Button.new()
	close.text = "Close"
	close.pressed.connect(func(): visible = false)
	box.add_child(close)
	visible = false


## Shows a `boss_loot` event: {"boss", "received": [{"hero", "name", "gold", "items"}], "seconds"}.
func show_summary(e: Dictionary) -> void:
	var lines: PackedStringArray = ["[b]%s defeated: loot[/b]" % e.get("boss", "Boss")]
	for r in e.get("received", []):
		lines.append(line_for(r))
	_text.text = "\n".join(lines)
	_until = Time.get_ticks_msec() / 1000.0 + float(e.get("seconds", 12.0))
	visible = true


## Adds a boss roll's winner (phase 2) to the open summary.
func add_line(text: String) -> void:
	if visible:
		_text.text += "\n" + text


## "Mara: 40 gold, Grizzly Pelt, [color]Grizzlehide Mantle[/color]".
static func line_for(r: Dictionary) -> String:
	var parts: PackedStringArray = []
	if int(r.get("gold", 0)) > 0:
		parts.append("%d gold" % r.gold)
	for pair in r.get("items", []):
		var item: ItemDef = ContentDB.items.get(StringName(str(pair[0])))
		var name := item.display_name if item != null else str(pair[0])
		if int(pair[1]) > 1:
			name += " x%d" % pair[1]
		parts.append("[color=%s]%s[/color]" % [Rarity.COLORS[item.rarity].to_html(false) if item else "000000", name])
	return "%s: %s" % [r.get("name", "?"), ", ".join(parts) if not parts.is_empty() else "nothing"]


func _process(_delta: float) -> void:
	if visible and Time.get_ticks_msec() / 1000.0 > _until:
		visible = false
