class_name ItemLabel
extends RichTextLabel
## An item's name (in its rarity's colour, plus any `suffix`: price, count) with
## the full item tooltip on hover, like an item slot: shop, trade and roll windows.
## Its icon comes first (see Icons).

var hud: Hud
var item: ItemDef


func _init(p_hud: Hud, p_item: ItemDef, suffix: String = "") -> void:
	hud = p_hud
	item = p_item
	bbcode_enabled = true
	fit_content = true
	mouse_filter = Control.MOUSE_FILTER_PASS # hover for the tooltip
	tooltip_text = item.display_name
	_suffix = suffix
	_write()


var _suffix := ""


## The icon (at a whole screen scale, so once it's in the window) before the name.
func _notification(what: int) -> void:
	if what == NOTIFICATION_ENTER_TREE:
		_write()


func _write() -> void:
	var icon := Icons.of_item(item)
	var img := Icons.bbcode(icon, Icons.screen_scale_of(self) if is_inside_tree() else -1.0) + " " if icon != null else ""
	text = "%s[color=#%s]%s[/color]%s" % [img, Rarity.color(item.rarity).to_html(false), item.display_name, _suffix]


func _make_custom_tooltip(_for_text: String) -> Object:
	return ItemTooltip.label(item, hud.session.local_hero(), hud.session.rules(), false, hud.session.now())
