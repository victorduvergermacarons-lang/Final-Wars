class_name MainMenu
extends CanvasLayer
## Title menu: player name, Play Solo, Host (port), Join (address + port).

signal solo_requested(player_name: String)
signal host_requested(player_name: String, port: int)
signal join_requested(player_name: String, address: String, port: int)

var _name: LineEdit
var _address: LineEdit
var _port: SpinBox
var _status: Label


func _ready() -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(360, 0)
	box.add_theme_constant_override("separation", 10)
	center.add_child(box)

	var title := Label.new()
	title.text = "Final Wars"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	box.add_child(title)

	_name = _field(box, "Your name", "Adventurer")
	box.add_child(_button("Play Solo", func(): solo_requested.emit(_player_name())))
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
	var host := _button("Host Game", func(): host_requested.emit(_player_name(), int(_port.value)))
	var join := _button("Join Game", func(): join_requested.emit(_player_name(), _address.text.strip_edges(), int(_port.value)))
	host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	join.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(host)
	row.add_child(join)
	box.add_child(row)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_status)


func show_status(text: String) -> void:
	_status.text = text


func _player_name() -> String:
	var n := _name.text.strip_edges()
	return n if not n.is_empty() else "Adventurer"


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
