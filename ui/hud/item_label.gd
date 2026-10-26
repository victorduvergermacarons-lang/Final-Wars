class_name ItemLabel
extends RichTextLabel
## An item's name (in its rarity's colour, plus any `suffix`: price, count) with
## the full item tooltip on hover, like an item slot: shop and loot lists.

var hud: Hud
var item: ItemDef


func _init(p_hud: Hud, p_item: ItemDef, suffix: String = "") -> void:
	hud = p_hud
	item = p_item
	bbcode_enabled = true
	fit_content = true
	mouse_filter = Control.MOUSE_FILTER_PASS # hover for the tooltip
	tooltip_text = item.display_name
	text = "[color=#%s]%s[/color]%s" % [Rarity.color(item.rarity).to_html(false), item.display_name, suffix]


func _make_custom_tooltip(_for_text: String) -> Object:
	return ItemTooltip.label(item, hud.session.local_hero(), hud.session.rules(), false, hud.session.now())
