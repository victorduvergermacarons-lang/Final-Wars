class_name BookSpread
extends Control
## A menu that fills the menu book: what goes on the left page in `left`, what
## goes on the right page in `right`. BookView.fit_pages() calls lay_out() with
## both pages' rects; a page whose content is too big is scaled down to fit it.

const TITLE_SIZE := 28
const NOTE_SIZE := 17

var left := VBoxContainer.new()
var right := VBoxContainer.new()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for page in [left, right]:
		page.add_theme_constant_override("separation", 8)
		add_child(page)


## Places each page's column on its page rect (in this control's coordinates).
func lay_out(left_rect: Rect2, right_rect: Rect2) -> void:
	_fit(left, left_rect)
	_fit(right, right_rect)


static func _fit(column: Control, room: Rect2) -> void:
	column.position = room.position
	column.size = Vector2(room.size.x, 0.0)
	var need := column.get_combined_minimum_size()
	var k := minf(1.0, minf(room.size.x / maxf(need.x, 1.0), room.size.y / maxf(need.y, 1.0)))
	column.scale = Vector2(k, k)
	column.size = Vector2(room.size.x / k, need.y)


## A page heading in the book's leather red.
static func title(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", TITLE_SIZE)
	l.add_theme_color_override("font_color", UiPalette.LEATHER_DARK)
	return l


## A small hint line in soft ink, wrapping to the page.
static func note(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", NOTE_SIZE)
	l.add_theme_color_override("font_color", UiPalette.INK_SOFT)
	return l


## The hero's bag as a grid of slots (inventory, shop and loot pages).
static func bag_grid(hud: Hud, columns: int = 5) -> GridContainer:
	var bag := GridContainer.new()
	bag.columns = columns
	bag.add_theme_constant_override("h_separation", 6)
	bag.add_theme_constant_override("v_separation", 6)
	for i in Bag.DEFAULT_SIZE:
		bag.add_child(ItemSlotView.new(hud, ItemSlotView.Kind.BAG, i))
	return bag
