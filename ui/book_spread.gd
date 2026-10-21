class_name BookSpread
extends Control
## A menu that fills the menu book: what goes on the left page in `left`, what
## goes on the right page in `right`. BookView lays it out for the book at 1080p
## and scales the whole menu to the book's real size, so nothing here is
## resampled at 1080p and text stays sharp. Content is laid out to fit its page;
## anything taller is cut off at the page's bottom (long lists scroll). How-to
## hints live in the Escape menu's Controls tab, not on the pages.

const TITLE_SIZE := 26
const NOTE_SIZE := 16
const SEPARATION := 4

var left := VBoxContainer.new()
var right := VBoxContainer.new()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for page in [left, right]:
		page.add_theme_constant_override("separation", SEPARATION)
		page.clip_contents = true
		add_child(page)


## Places each page's column on its page rect (this control's coordinates).
func lay_out(left_rect: Rect2, right_rect: Rect2) -> void:
	_place(left, left_rect)
	_place(right, right_rect)


static func _place(column: Control, room: Rect2) -> void:
	column.position = room.position.round()
	column.size = room.size.round()


## A page heading in the book's leather red.
static func title(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", TITLE_SIZE)
	l.add_theme_color_override("font_color", UiPalette.LEATHER_DARK)
	return l


## A small line in soft ink, wrapping to the page.
static func note(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", NOTE_SIZE)
	l.add_theme_color_override("font_color", UiPalette.INK_SOFT)
	return l


## The hero's bag as a grid of slots (inventory, shop and loot pages), centred.
static func bag_grid(hud: Hud, columns: int = 5) -> GridContainer:
	var bag := GridContainer.new()
	bag.columns = columns
	bag.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	bag.add_theme_constant_override("h_separation", 6)
	bag.add_theme_constant_override("v_separation", 6)
	for i in Bag.DEFAULT_SIZE:
		bag.add_child(ItemSlotView.new(hud, ItemSlotView.Kind.BAG, i))
	return bag
