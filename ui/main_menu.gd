class_name MainMenu
extends CanvasLayer
## Title menu: pick or create a character, then Play Solo, Host (port) or Join
## (address + port). Characters are saved on this computer.

signal solo_requested(character: Dictionary)
signal host_requested(character: Dictionary, port: int)
signal join_requested(character: Dictionary, address: String, port: int)

var store: CharacterStore
var _characters: OptionButton
var _new_name: LineEdit
var _address: LineEdit
var _port: SpinBox
var _status: Label


func _ready() -> void:
	# Written in the menu book: the title and your character on the left page,
	# how to play on the right.
	var book := BookView.new(false)
	book.auto_fit = false
	add_child(book)
	var box := _page(book.left_page)

	var title := Label.new()
	title.text = "Final Wars"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", UiPalette.LEATHER_DARK)
	box.add_child(title)

	var pick_label := Label.new()
	pick_label.text = "Character"
	box.add_child(pick_label)
	_characters = OptionButton.new()
	box.add_child(_characters)
	var create_row := HBoxContainer.new()
	_new_name = LineEdit.new()
	_new_name.placeholder_text = "New character name"
	_new_name.max_length = 16
	_new_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	create_row.add_child(_new_name)
	create_row.add_child(_button("Create", _on_create))
	box.add_child(create_row)
	_refresh_characters("")

	box = _page(book.right_page)
	box.add_child(_button("Play Solo", func(): _start(func(c): solo_requested.emit(c))))
	box.add_child(HSeparator.new())
	_address = _field(box, "Host address (to join)", "127.0.0.1")
	var port_row := HBoxContainer.new()
	var port_label := Label.new()
	port_label.text = "Port"
	port_row.add_child(port_label)
	_port = SpinBox.new()
	_port.min_value = 1024
	_port.max_value = 65535
	_port.value = Net.DEFAULT_PORT
	_port.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	port_row.add_child(_port)
	box.add_child(port_row)
	var row := HBoxContainer.new()
	var host := _button("Host Game", func(): _start(func(c): host_requested.emit(c, int(_port.value))))
	var join := _button("Join Game", func(): _start(func(c): join_requested.emit(c, _address.text.strip_edges(), int(_port.value))))
	host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	join.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(host)
	row.add_child(join)
	box.add_child(row)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_status)


## A column filling a page of the book.
func _page(page: Control) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.add_theme_constant_override("separation", 10)
	page.add_child(box)
	return box


func show_status(text: String) -> void:
	_status.text = text


## The selected character's saved data, or {} if none.
func selected_character() -> Dictionary:
	if _characters.selected < 0 or _characters.item_count == 0:
		return {}
	return store.load_character(_characters.get_item_text(_characters.selected))


func _start(emit: Callable) -> void:
	var c := selected_character()
	if c.is_empty():
		show_status("Create a character first.")
		return
	emit.call(c)


func _on_create() -> void:
	var char_name := CharacterData.clean_name(_new_name.text)
	if store.exists(char_name):
		show_status("%s already exists." % char_name)
	else:
		store.save(CharacterData.new_character(char_name, ContentDB.heroes[&"adventurer"]))
		show_status("Created %s." % char_name)
	_new_name.text = ""
	_refresh_characters(char_name)


func _refresh_characters(select: String) -> void:
	_characters.clear()
	for n in store.list():
		_characters.add_item(n)
		if n == select:
			_characters.select(_characters.item_count - 1)


func _field(parent: Control, label_text: String, value: String) -> LineEdit:
	var label := Label.new()
	label.text = label_text
	parent.add_child(label)
	var edit := LineEdit.new()
	edit.text = value
	parent.add_child(edit)
	return edit


func _button(text: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(on_press)
	return b
