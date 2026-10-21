extends GutTest
## The menu book: dragging its top edge moves it, never off screen.

var book: BookView


func before_each() -> void:
	# A screen-sized parent, like the HUD's root, so the book has room to move.
	var screen := Control.new()
	screen.size = Vector2(1280, 720)
	add_child_autofree(screen)
	book = BookView.new()
	book.window_size_override = Vector2(1920, 1080) # headless windows are 64×64
	screen.add_child(book)
	await get_tree().process_frame


func _drag(by: Vector2) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	book._on_handle_input(press)
	var move := InputEventMouseMotion.new()
	move.relative = by
	book._on_handle_input(move)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	book._on_handle_input(release)


func test_dragging_the_top_moves_the_book_and_its_pages() -> void:
	var start := book.book_rect.position
	var page := book.spread.position
	_drag(Vector2(-40, 30))
	assert_almost_eq(book.book_rect.position.x, start.x - 40, 1.0)
	assert_almost_eq(book.book_rect.position.y, start.y + 30, 1.0)
	assert_almost_eq(book.spread.position.x - page.x, book.book_rect.position.x - start.x, 0.01, "the pages go with it")


func test_moving_without_holding_does_nothing() -> void:
	var start := book.book_rect.position
	var move := InputEventMouseMotion.new()
	move.relative = Vector2(50, 50)
	book._on_handle_input(move)
	assert_eq(book.book_rect.position, start)


func test_the_handle_stays_on_screen() -> void:
	_drag(Vector2(-10000, -10000))
	var handle := book.page_rect(Rect2(BookView.SIDES.x, BookView.TOP_EDGE, BookView.SIDES.y - BookView.SIDES.x, 1))
	assert_gte(handle.end.x, BookView.KEEP_VISIBLE.x - 1.0, "some of the top edge is still on screen")
	assert_gte(handle.position.y, -1.0)
	_drag(Vector2(10000, 10000))
	handle = book.page_rect(Rect2(BookView.SIDES.x, BookView.TOP_EDGE, BookView.SIDES.y - BookView.SIDES.x, 1))
	assert_lte(handle.position.x, book.size.x - BookView.KEEP_VISIBLE.x + 1.0)
	assert_lte(handle.position.y, book.size.y - BookView.KEEP_VISIBLE.y + 1.0)
