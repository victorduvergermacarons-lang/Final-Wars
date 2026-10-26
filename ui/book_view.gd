class_name BookView
extends Control
## The menu book (assets/ui/menu_book.png, Layer 1 of art/menu_book.aseprite)
## filling the screen (exactly 4 screen pixels per art pixel at 1080p), and moved
## by dragging its top edge. Menus go on its pages: a BookSpread in `spread` uses
## both pages; `left_page` / `right_page` hold content laid out by its own
## anchors (main menu). Uses the paper theme.

signal close_requested
## The page-turn arrows at the bottom: -1 back, +1 forward (the HUD picks the menu).
signal turn_requested(direction: int)

const TEXTURE := preload("res://assets/ui/menu_book.png")
const ART_SIZE := Vector2(480, 270)
## Writable areas in art pixels, inside the page borders (measured on the art).
const LEFT_PAGE := Rect2(66, 46, 166, 174)
const RIGHT_PAGE := Rect2(250, 46, 158, 174)
## The book's top edge and its left and right edges (art), for the Close button
## and the drag handle along the top.
const TOP_EDGE := 37.0
const SIDES := Vector2(35, 438)
## Menus (BookSpread) are laid out for this many UI units per art pixel: the book
## at 1080p. A smaller book scales them as a whole; at 1080p they are drawn 1:1,
## so text stays sharp.
const REF_ART_SCALE := 8.0 / 3.0
## How much of the book must stay on screen when it is dragged (UI units).
const KEEP_VISIBLE := Vector2(160, 60)
## The page-turn arrows' text size (they sit in the margin under the pages).
const TURN_FONT_SIZE := 16

var left_page := Control.new()
var right_page := Control.new()
var spread := Control.new()
var close_button: Button
var prev_button: Button
var next_button: Button
## Book rect in this control's coordinates, and UI units per art pixel.
var book_rect := Rect2()
var art_scale := 1.0
## Lay the spread's menus out (fit_pages) whenever the book is laid out.
var auto_fit := true
## The open menu's own drawing over the book (BookSpread.page_art), or null.
var page_art: Texture2D:
	set(value):
		if value != page_art:
			page_art = value
			queue_redraw()
## Where the player dragged the book, from its centred place (UI units).
var offset := Vector2.ZERO
var _handle := Control.new()
var _dragging := false
var _stretch := 1.0
## Tests: the window size to lay out for (headless windows are tiny).
var window_size_override := Vector2.ZERO


func _init(with_close: bool = true) -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP # menus are open: clicks don't reach the world
	theme = UiPalette.paper_theme()
	for page in [left_page, right_page, spread]:
		page.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(page)
	# The top edge of the book is its handle: drag it to move the book.
	_handle.mouse_default_cursor_shape = Control.CURSOR_MOVE
	_handle.tooltip_text = "Drag to move the book"
	_handle.gui_input.connect(_on_handle_input)
	add_child(_handle)
	if with_close:
		close_button = Button.new()
		close_button.text = "Close"
		close_button.focus_mode = Control.FOCUS_NONE
		close_button.pressed.connect(func(): close_requested.emit())
		add_child(close_button)
		# Page-turn arrows under the pages' bottom corners.
		prev_button = _turn_button(-1)
		next_button = _turn_button(1)
	resized.connect(_layout)


func _turn_button(direction: int) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", TURN_FONT_SIZE)
	b.pressed.connect(func(): turn_requested.emit(direction))
	add_child(b)
	return b


## Names the menus the arrows lead to ("< Inventory", "Trees >").
func set_turn_labels(previous: String, next: String) -> void:
	if prev_button == null:
		return
	var p := "<  " + previous
	var n := next + "  >"
	if prev_button.text != p or next_button.text != n:
		prev_button.text = p
		next_button.text = n
		_place_turn_buttons()


func _place_turn_buttons() -> void:
	if prev_button == null:
		return
	var y := book_rect.position.y + (LEFT_PAGE.end.y + 3.0) * art_scale
	for b in [prev_button, next_button]:
		b.size = b.get_combined_minimum_size()
	prev_button.position = Vector2(book_rect.position.x + LEFT_PAGE.position.x * art_scale, y).round()
	next_button.position = Vector2(book_rect.position.x + RIGHT_PAGE.end.x * art_scale - next_button.size.x, y).round()


func _ready() -> void:
	# The UI keeps its 1280×720 size when the window is resized, so watch the window.
	get_window().size_changed.connect(_layout)
	_layout()


func _draw() -> void:
	draw_texture_rect(TEXTURE, book_rect, false)
	if page_art != null:
		draw_texture_rect(page_art, book_rect, false)


## The page `rect` (art pixels) in this control's coordinates.
func page_rect(rect: Rect2) -> Rect2:
	return Rect2(book_rect.position + rect.position * art_scale, rect.size * art_scale)


## How much the menus are scaled: 1 at 1080p (exactly, so text isn't resampled).
func content_scale() -> float:
	var k := art_scale / REF_ART_SCALE
	return 1.0 if absf(k - 1.0) < 0.01 else k


## Lays out the menu in the spread over both pages. Call when content changes.
func fit_pages() -> void:
	var k := content_scale()
	for w in spread.get_children():
		if w is BookSpread and w.visible:
			w.position = Vector2.ZERO
			w.scale = Vector2(k, k)
			w.size = spread.size / k
			var s := REF_ART_SCALE
			w.lay_out(Rect2(Vector2.ZERO, LEFT_PAGE.size * s),
					Rect2(((RIGHT_PAGE.position - LEFT_PAGE.position) * s).round(), RIGHT_PAGE.size * s))


func _on_handle_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
		accept_event()
	elif event is InputEventMouseMotion and _dragging:
		offset += event.relative
		_layout()
		accept_event()


func _layout() -> void:
	var view := size
	var window := window_size_override if window_size_override != Vector2.ZERO else (
			Vector2(get_window().size) if is_inside_tree() else view)
	# Screen pixels per UI unit (the window stretches the 1280×720 UI).
	_stretch = minf(window.x / maxf(view.x, 1.0), window.y / maxf(view.y, 1.0))
	if _stretch <= 0.0:
		_stretch = 1.0
	# The book fills the 1280×720 UI, so menus are drawn at their real size (sharp
	# text) whatever the window. At 1080p that is exactly 4 screen pixels per art
	# pixel; other window sizes give uneven art pixels rather than blurred text.
	art_scale = minf(view.x / ART_SIZE.x, view.y / ART_SIZE.y)
	var book_size := ART_SIZE * art_scale
	# Dragged, but never so far that the handle leaves the screen.
	var centred := (view - book_size) * 0.5
	var lo := Vector2(KEEP_VISIBLE.x - SIDES.y * art_scale, -TOP_EDGE * art_scale)
	var hi := Vector2(view.x - KEEP_VISIBLE.x - SIDES.x * art_scale, view.y - KEEP_VISIBLE.y - TOP_EDGE * art_scale)
	offset = (centred + offset).clamp(lo, hi) - centred
	# On whole screen pixels, so every art pixel is the same size.
	var corner := ((centred + offset) * _stretch).floor() / _stretch
	book_rect = Rect2(corner, book_size)
	_set_rect(left_page, page_rect(LEFT_PAGE))
	_set_rect(right_page, page_rect(RIGHT_PAGE))
	_set_rect(spread, page_rect(Rect2(LEFT_PAGE.position, RIGHT_PAGE.end - LEFT_PAGE.position)))
	_set_rect(_handle, page_rect(Rect2(SIDES.x, TOP_EDGE - 4.0, SIDES.y - SIDES.x, LEFT_PAGE.position.y - TOP_EDGE + 4.0)))
	if close_button != null:
		var b := close_button.get_combined_minimum_size()
		close_button.size = b
		close_button.position = Vector2(book_rect.position.x + RIGHT_PAGE.end.x * art_scale - b.x,
				book_rect.position.y + TOP_EDGE * art_scale - b.y - 2.0)
	_place_turn_buttons()
	if auto_fit:
		fit_pages()
	queue_redraw()


static func _set_rect(c: Control, r: Rect2) -> void:
	c.position = r.position
	c.size = r.size
