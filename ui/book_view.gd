class_name BookView
extends Control
## The menu book (assets/ui/menu_book.png, Layer 1 of art/menu_book.aseprite)
## drawn in the middle of the screen at the largest whole number of screen
## pixels per art pixel that fits (4 at 1080p: the 480×270 art fills the
## screen). Menus go on its pages: `left_page`, `right_page`, or `spread` (both
## pages, for big windows). Children of the pages are laid out by fit_pages():
## top-centred, scaled down if they don't fit. Uses the paper theme.

signal close_requested

const TEXTURE := preload("res://assets/ui/menu_book.png")
const ART_SIZE := Vector2(480, 270)
## Writable areas in art pixels, inside the page borders (measured on the art).
const LEFT_PAGE := Rect2(66, 46, 166, 174)
const RIGHT_PAGE := Rect2(250, 46, 158, 174)
## The book's top edge (art y), for the Close button above it.
const TOP_EDGE := 37.0

var left_page := Control.new()
var right_page := Control.new()
var spread := Control.new()
var close_button: Button
## Book rect in this control's coordinates, and UI units per art pixel.
var book_rect := Rect2()
var art_scale := 1.0
## Fit the pages' children (fit_pages) whenever the book is laid out.
## Off for pages whose content fills them by its own anchors (main menu).
var auto_fit := true


func _init(with_close: bool = true) -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP # menus are open: clicks don't reach the world
	theme = UiPalette.paper_theme()
	for page in [left_page, right_page, spread]:
		page.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(page)
	if with_close:
		close_button = Button.new()
		close_button.text = "Close"
		close_button.focus_mode = Control.FOCUS_NONE
		close_button.pressed.connect(func(): close_requested.emit())
		add_child(close_button)
	resized.connect(_layout)


func _ready() -> void:
	# The UI keeps its 1280×720 size when the window is resized, so watch the window.
	get_window().size_changed.connect(_layout)
	_layout()


func _draw() -> void:
	draw_texture_rect(TEXTURE, book_rect, false)


## The page `rect` (art pixels) in this control's coordinates.
func page_rect(rect: Rect2) -> Rect2:
	return Rect2(book_rect.position + rect.position * art_scale, rect.size * art_scale)


## Lays out each child of the pages: at its minimum size, scaled down to fit the
## page if needed, centred across the top. Call after content changes size.
func fit_pages() -> void:
	for page in [left_page, right_page, spread]:
		for w in page.get_children():
			if w is BookSpread and w.visible:
				# Both pages, in the spread's coordinates.
				w.position = Vector2.ZERO
				w.size = page.size
				w.lay_out(Rect2(Vector2.ZERO, LEFT_PAGE.size * art_scale),
						Rect2((RIGHT_PAGE.position - LEFT_PAGE.position) * art_scale, RIGHT_PAGE.size * art_scale))
			elif w is Control and w.visible:
				_fit(w, page.size)


static func _fit(w: Control, room: Vector2) -> void:
	var need := w.get_combined_minimum_size()
	if need.x <= 0.0 or need.y <= 0.0:
		return
	w.size = need
	var k := minf(1.0, minf(room.x / need.x, room.y / need.y))
	w.scale = Vector2(k, k)
	w.position = Vector2(floorf((room.x - need.x * k) * 0.5), 0.0)


func _layout() -> void:
	var view := size
	var window := Vector2(get_window().size) if is_inside_tree() else view
	# Screen pixels per UI unit (the window stretches the 1280×720 UI).
	var stretch := minf(window.x / maxf(view.x, 1.0), window.y / maxf(view.y, 1.0))
	if stretch <= 0.0:
		stretch = 1.0
	var screen_scale := maxf(1.0, floorf(minf(window.x / ART_SIZE.x, window.y / ART_SIZE.y)))
	art_scale = screen_scale / stretch
	var book_size := ART_SIZE * art_scale
	# On whole screen pixels, so every art pixel is the same size.
	var corner := ((view - book_size) * 0.5 * stretch).floor() / stretch
	book_rect = Rect2(corner, book_size)
	_set_rect(left_page, page_rect(LEFT_PAGE))
	_set_rect(right_page, page_rect(RIGHT_PAGE))
	_set_rect(spread, page_rect(Rect2(LEFT_PAGE.position, RIGHT_PAGE.end - LEFT_PAGE.position)))
	if close_button != null:
		var b := close_button.get_combined_minimum_size()
		close_button.size = b
		close_button.position = Vector2(book_rect.position.x + RIGHT_PAGE.end.x * art_scale - b.x,
				book_rect.position.y + TOP_EDGE * art_scale - b.y - 2.0)
	if auto_fit:
		fit_pages()
	queue_redraw()


static func _set_rect(c: Control, r: Rect2) -> void:
	c.position = r.position
	c.size = r.size
