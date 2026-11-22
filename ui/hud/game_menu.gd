class_name GameMenu
extends PanelContainer
## The Escape menu: Resume, Leave game, and four tabs: the message log
## (everything that has happened this session), the controls (keyboard and
## controller, and every how-to), the volumes
## (Sound), and test settings (game speed). Plain boxes
## for now (Godot's default look), not the menu book.

## The Controls tab: one row per control, keyboard and controller (from
## InputActions, so it always matches the game), then how things work.
const CONTROL_ROWS := [
	["Move", "WASD (two keys walk along the grid)", "Left stick (any angle)"],
	["Aim", "The mouse", "Right stick, or auto-lock (Gameplay test tab)"],
	["Weapon (tap; hold 3 s for its second move)", &"action_slot_1"],
	["Element move (Y)", &"action_slot_2"],
	["Element move (A)", &"action_slot_3"],
	["Element move (B)", &"action_slot_4"],
	["Switch mode (Water / Ice)", &"timing_press"],
	["Element power", &"element_power"],
	["Talk, use, pick up; release when dead", &"interact"],
	["Next target", &"target_next"],
	["Clear target, cancel aim", &"cancel_aim"],
	["Health potion", &"potion_health"],
	["Mana potion", &"potion_mana"],
	["Menu book (inventory)", &"toggle_inventory"],
	["Cancel cast, close menus, this menu", &"target_clear"],
]

const CONTROLS_NOTES := """[b]Your element's moves[/b] (the wheel, bottom right, shows them)
Fire: Y Fire Dart (hold 1 s: Fire Whip) · A Flame Dash · B Punch, Punch, Kick
Water: Y Water Whip · A Water Pulse · B Healing Touch · switch to Ice: Y Frost Shard · A Ice Slide · B Frost Ring
Earth: Y Stone Fist (hold: Rock Throw; punch your pillar to slide it) · A Stone Skin, tap up to 3 times (hold: taunt) · B hold to raise a pillar in front, taller the longer
Air: Y Air Blast · A Air Step, a long dash that fills a wind dot · B Air Palm; Palm and Blast spend the dots for more damage and push (3: a stun)
Heals on allies: press, choose an ally with the left stick or arrows, press again.
Weapons on X: sword Slash (hold: Lunge), bow Quick Shot (hold: Aimed Shot), hammer Smash (hold: Ground Slam).
Attacks go where you aim: no target needed.
Mouse wheel: zoom.

[b]Menus[/b] (the menu book)
P Spellbook · T Ability trees · C Character · B Inventory · L Quests
Drag an ability from the Spellbook or the trees onto a slot of the wheel (bottom right).
Drag the book's top edge to move it.

[b]Inventory[/b]
Drag to move or equip · right-click to equip or take off
Shift+click to split a stack · Ctrl+right-click to destroy
Drop a scroll (or your weapon) on the learning slot to learn its ability.

[b]Shop[/b]
Right-click an item in your bag to sell it. Drag the shop by its title to move it."""


## The Controls tab's text.
static func controls_text() -> String:
	var table := "[table=3][cell][b]Action[/b]   [/cell][cell][b]Keyboard / mouse[/b]   [/cell][cell][b]Controller[/b][/cell]"
	for row in CONTROL_ROWS:
		var keys: String
		var pad: String
		if row.size() == 3:
			keys = row[1]
			pad = row[2]
		else:
			keys = InputActions.hint(row[1], InputDevice.Kind.KEYBOARD)
			pad = InputActions.hint(row[1], InputDevice.Kind.GAMEPAD)
		table += "[cell]%s   [/cell][cell]%s   [/cell][cell]%s[/cell]" % [row[0], keys if keys != "" else "—",
				pad if pad != "" else "—"]
	return "[b]Controls[/b] (keyboard and mouse · controller)\n" + table + "[/table]\n\n" + CONTROLS_NOTES

var hud: Hud
var _log: RichTextLabel
var _shown_lines := -1
var _controls: RichTextLabel
var _controls_revision := -1
var _speed_slider: HSlider
var _speed_box: SpinBox
var _dungeon_testing: CheckBox
var _timing_bars: CheckBox
## The Sound tab: a volume slider per audio bus, saved per player.
var sound: SettingsWindow


func _init(p_hud: Hud) -> void:
	hud = p_hud
	custom_minimum_size = Vector2(640, 460)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.08, 0.1, 0.96)
	bg.border_color = Color(0.35, 0.35, 0.4)
	bg.set_border_width_all(1)
	bg.set_corner_radius_all(4)
	bg.set_content_margin_all(14)
	add_theme_stylebox_override("panel", bg)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	add_child(box)
	var title := Label.new()
	title.text = "Menu"
	title.add_theme_font_size_override("font_size", 24)
	box.add_child(title)
	var buttons := HBoxContainer.new()
	box.add_child(buttons)
	buttons.add_child(_button("Resume (Esc)", func(): visible = false))
	buttons.add_child(_button("Leave game", func(): hud.leave_requested.emit()))
	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(tabs)
	_log = _text_tab(tabs, "Log")
	_log.scroll_following = true
	_controls = _text_tab(tabs, "Controls")
	sound = SettingsWindow.new()
	sound.name = "Sound"
	sound.embedded = true
	sound.settings_path = hud.settings_path
	tabs.add_child(sound)
	tabs.add_child(_speed_tab())
	visible = false


## "Gameplay test": the game speed (CombatRules.game_speed), as a slider
## and a box for an exact value. Sent to the host, which applies it to everyone.
func _speed_tab() -> Control:
	var page := VBoxContainer.new()
	page.name = "Gameplay test"
	page.add_theme_constant_override("separation", 10)
	var about := Label.new()
	about.text = "Game speed: the whole game runs at this speed, in and out of combat:\nwalking, steps, cooldowns, wind-ups, casts, projectiles, buffs, regen and respawns,\nfor heroes and enemies alike. ×2 = twice as fast, ×0.1 = ten times slower.\nApplies to everyone in the session (debug builds only)."
	page.add_child(about)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	page.add_child(row)
	var label := Label.new()
	label.text = "Game speed ×"
	row.add_child(label)
	_speed_slider = HSlider.new()
	_speed_slider.min_value = CombatRules.GAME_SPEED_MIN
	_speed_slider.max_value = CombatRules.GAME_SPEED_MAX
	_speed_slider.step = 0.05
	_speed_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_speed_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_speed_slider.focus_mode = Control.FOCUS_NONE
	row.add_child(_speed_slider)
	_speed_box = SpinBox.new()
	_speed_box.min_value = CombatRules.GAME_SPEED_MIN
	_speed_box.max_value = CombatRules.GAME_SPEED_MAX
	_speed_box.step = 0.01
	_speed_box.custom_minimum_size.x = 100
	row.add_child(_speed_box)
	page.add_child(_button("Reset to ×1", func(): _set_speed(1.0)))

	# Where the timing bar (right-click on its green / yellow zones) is drawn.
	page.add_child(HSeparator.new())
	var place_row := HBoxContainer.new()
	place_row.add_theme_constant_override("separation", 10)
	page.add_child(place_row)
	var place_label := Label.new()
	place_label.text = "Timing bar"
	place_row.add_child(place_label)
	var place := OptionButton.new()
	place.focus_mode = Control.FOCUS_NONE
	place.add_item("Under your hero", TimingBarView.Place.BELOW_HERO)
	place.add_item("At the bottom of the screen", TimingBarView.Place.ACTION_BAR)
	place.select(place.get_item_index(hud.timing_bar.place))
	place.item_selected.connect(func(i: int): hud.set_timing_bar_place(place.get_item_id(i)))
	place_row.add_child(place)
	# Both modes move at the same speed (the full bar = FULL_SECONDS).
	var mode := OptionButton.new()
	mode.focus_mode = Control.FOCUS_NONE
	mode.add_item("Bar length follows the ability (full bar = %d s)" % int(TimingBarView.FULL_SECONDS), TimingBarView.Mode.LENGTH)
	mode.add_item("Zones slide to a fixed hit line", TimingBarView.Mode.SCROLL)
	mode.select(mode.get_item_index(hud.timing_bar.mode))
	mode.item_selected.connect(func(i: int): hud.set_timing_bar_mode(mode.get_item_id(i)))
	page.add_child(mode)
	# How the controller aims when the right stick is let go.
	var aim_row := HBoxContainer.new()
	aim_row.add_theme_constant_override("separation", 10)
	page.add_child(aim_row)
	var aim_label := Label.new()
	aim_label.text = "Controller aim"
	aim_row.add_child(aim_label)
	var aim := OptionButton.new()
	aim.focus_mode = Control.FOCUS_NONE
	aim.add_item("Auto-lock: the nearest enemy ahead (the right stick overrides)", ClientState.PadAim.AUTO_LOCK)
	aim.add_item("Twin-stick: always the right stick", ClientState.PadAim.TWIN_STICK)
	aim.select(aim.get_item_index(hud.client.pad_aim))
	aim.item_selected.connect(func(i: int): hud.set_pad_aim(aim.get_item_id(i)))
	aim_row.add_child(aim)
	# The timing bar mechanic itself, on or off (off: abilities go off at once).
	_timing_bars = CheckBox.new()
	_timing_bars.focus_mode = Control.FOCUS_NONE
	_timing_bars.text = "Timing bars: play abilities through their timing bar (off: they go off at once)"
	_timing_bars.set_pressed_no_signal(hud.session.rules().timing_bars_enabled)
	_timing_bars.toggled.connect(func(on: bool):
		hud.session.send_intent({"type": "timing_bars", "on": on}))
	page.add_child(_timing_bars)
	# Dungeons: the smallest party allowed in (CombatRules.min_dungeon_party).
	page.add_child(HSeparator.new())
	_dungeon_testing = CheckBox.new()
	_dungeon_testing.focus_mode = Control.FOCUS_NONE
	_dungeon_testing.text = "Dungeon testing: enter dungeons with any party size (the real game needs %d players)" \
			% hud.session.rules().dungeon_min_party
	_dungeon_testing.set_pressed_no_signal(hud.session.rules().dungeon_testing)
	_dungeon_testing.toggled.connect(func(on: bool):
		hud.session.send_intent({"type": "dungeon_testing", "on": on}))
	page.add_child(_dungeon_testing)
	show_speed(hud.session.rules().game_speed)
	# Dragging sends only on release, so the host isn't flooded while dragging.
	_speed_slider.value_changed.connect(func(v: float): _speed_box.set_value_no_signal(v))
	_speed_slider.drag_ended.connect(func(changed: bool):
		if changed:
			_set_speed(_speed_slider.value))
	_speed_box.value_changed.connect(_set_speed)
	return page


## Shows the timing bars setting without sending it.
func show_timing_bars(on: bool) -> void:
	if _timing_bars != null:
		_timing_bars.set_pressed_no_signal(on)


## Shows the dungeon testing setting without sending it.
func show_dungeon_testing(on: bool) -> void:
	if _dungeon_testing != null:
		_dungeon_testing.set_pressed_no_signal(on)


## Shows `value` without sending it (the host's answer, or the value on opening).
func show_speed(value: float) -> void:
	_speed_slider.set_value_no_signal(value)
	_speed_box.set_value_no_signal(value)


func _set_speed(value: float) -> void:
	show_speed(value)
	hud.session.send_intent({"type": "game_speed", "value": value})


static func speed_text(value: float) -> String:
	return String.num(value, 2)


func _process(_delta: float) -> void:
	if not visible:
		return
	if _controls_revision != InputDevice.revision:
		_controls_revision = InputDevice.revision
		_controls.text = controls_text()
	var lines: Array[String] = hud.client.history
	if lines.size() != _shown_lines:
		_shown_lines = lines.size()
		_log.text = "\n".join(lines) if not lines.is_empty() else "Nothing has happened yet."


static func _text_tab(tabs: TabContainer, tab_name: String) -> RichTextLabel:
	var t := RichTextLabel.new()
	t.name = tab_name
	t.bbcode_enabled = true
	t.selection_enabled = true
	t.add_theme_constant_override("line_separation", 3)
	tabs.add_child(t)
	return t


static func _button(text: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(on_press)
	return b
