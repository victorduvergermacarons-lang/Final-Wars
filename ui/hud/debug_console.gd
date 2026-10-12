class_name DebugConsole
extends PanelContainer
## Debug console (`): type a command and press Enter; the host runs it on your
## hero (debug builds only). "help" lists the commands. Up/Down recall earlier lines.

const MAX_LINES := 14

var hud: Hud
var input: LineEdit
var _log: RichTextLabel
var _lines: PackedStringArray = []
var _history: PackedStringArray = []
var _history_at := 0


func _init(p_hud: Hud) -> void:
	hud = p_hud
	custom_minimum_size = Vector2(560, 0)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.03, 0.03, 0.05, 0.92)
	bg.set_content_margin_all(8)
	add_theme_stylebox_override("panel", bg)
	var box := VBoxContainer.new()
	add_child(box)
	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.fit_content = true
	_log.scroll_active = false
	_log.custom_minimum_size = Vector2(540, 0)
	box.add_child(_log)
	input = LineEdit.new()
	input.placeholder_text = "Debug command (help for the list) — ` to close"
	input.text_submitted.connect(_submit)
	input.gui_input.connect(_on_input_key)
	box.add_child(input)
	print_line("[color=#a8a8b0]Debug console. Type help.[/color]")


func open() -> void:
	visible = true
	input.grab_focus.call_deferred()


func close() -> void:
	visible = false
	input.release_focus()


func print_line(text: String) -> void:
	_lines.append(text)
	if _lines.size() > MAX_LINES:
		_lines = _lines.slice(_lines.size() - MAX_LINES)
	_log.text = "\n".join(_lines)


## A debug event from the host for our hero.
func show_result(e: Dictionary) -> void:
	var color := "#5fe36b" if e.get("ok", false) else "#ff6b5b"
	for line in String(e.get("text", "")).split("\n"):
		print_line("[color=%s]%s[/color]" % [color, line.replace("[", "[lb]")])


func _submit(text: String) -> void:
	var line := text.strip_edges()
	input.clear()
	if line == "":
		return
	_history.append(line)
	_history_at = _history.size()
	print_line("> " + line.replace("[", "[lb]"))
	hud.session.send_intent({"type": "debug", "line": line.left(200)})


func _on_input_key(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed:
		return
	match event.physical_keycode:
		KEY_QUOTELEFT, KEY_ESCAPE:
			close()
			input.accept_event()
		KEY_UP:
			if not _history.is_empty():
				_history_at = maxi(_history_at - 1, 0)
				input.text = _history[_history_at]
				input.caret_column = input.text.length()
			input.accept_event()
		KEY_DOWN:
			_history_at = mini(_history_at + 1, _history.size())
			input.text = _history[_history_at] if _history_at < _history.size() else ""
			input.caret_column = input.text.length()
			input.accept_event()
