class_name ItemButton
extends Button
## A button naming an item, with the full item tooltip (stats, comparison) on hover.

var hud: Hud
var item: ItemDef


func _init(p_hud: Hud, p_item: ItemDef, label: String) -> void:
	hud = p_hud
	item = p_item
	text = label
	tooltip_text = item.display_name
	alignment = HORIZONTAL_ALIGNMENT_LEFT
	focus_mode = Control.FOCUS_NONE
	add_theme_color_override("font_color", Rarity.color(item.rarity))


func _make_custom_tooltip(_for_text: String) -> Object:
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.custom_minimum_size = Vector2(300, 0)
	label.text = ItemTooltip.text(item, hud.session.local_hero(), hud.session.rules(), false)
	return label
