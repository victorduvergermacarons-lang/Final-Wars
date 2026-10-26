class_name SettingsWindow
extends PanelContainer
## Settings: a volume slider per audio bus (Master, Music, Ambience, SFX, UI).
## Changes apply at once and are saved on this computer (user://settings.cfg,
## [audio]) when a slider is released or the window closes.

const LABELS := {"Master": "Master", "Music": "Music", "Ambience": "Ambience", "SFX": "Sound effects", "UI": "Interface"}

var settings_path := SettingsStore.DEFAULT_PATH
## Inside another window (the Escape menu's Sound tab): no title, no Close, no box.
var embedded := false
var sliders := {} # bus -> HSlider
var _values := {} # bus -> Label


func _ready() -> void:
	custom_minimum_size = Vector2(340, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	add_child(box)
	if embedded:
		add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	else:
		var title := Label.new()
		title.text = "Settings"
		title.add_theme_font_size_override("font_size", 20)
		box.add_child(title)
	var sound := Label.new()
	sound.text = "Volume"
	box.add_child(sound)
	for bus in AudioConfig.BUSES:
		var row := HBoxContainer.new()
		var name := Label.new()
		name.text = LABELS.get(bus, bus)
		name.custom_minimum_size = Vector2(110, 0)
		row.add_child(name)
		var s := HSlider.new()
		s.min_value = 0
		s.max_value = 100
		s.step = 1
		s.focus_mode = Control.FOCUS_NONE
		s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		s.custom_minimum_size = Vector2(160, 0)
		s.value = roundf(Audio.get_volume(bus) * 100.0)
		s.value_changed.connect(_on_changed.bind(bus))
		s.drag_ended.connect(func(_changed): save())
		row.add_child(s)
		var value := Label.new()
		value.custom_minimum_size = Vector2(40, 0)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value.text = "%d%%" % int(s.value)
		row.add_child(value)
		box.add_child(row)
		sliders[bus] = s
		_values[bus] = value
	if not embedded:
		var close := Button.new()
		close.text = "Close"
		close.focus_mode = Control.FOCUS_NONE
		close.pressed.connect(func():
			save()
			Audio.play(&"ui_close")
			visible = false)
		box.add_child(close)
	visibility_changed.connect(_refresh)


func _on_changed(value: float, bus: String) -> void:
	Audio.set_volume(bus, value / 100.0)
	_values[bus].text = "%d%%" % int(value)


func save() -> void:
	Audio.save_volumes(settings_path)


## Shows the current volumes when opened.
func _refresh() -> void:
	if not visible:
		return
	for bus in sliders:
		sliders[bus].set_value_no_signal(roundf(Audio.get_volume(bus) * 100.0))
		_values[bus].text = "%d%%" % int(sliders[bus].value)
