class_name GameMenu
extends PanelContainer
## The Escape menu: Resume, Keybinds, Leave game, and three tabs: the message log
## (everything that has happened this session), the controls (every how-to that
## used to sit on screen and in the menus), and how keybinding works. Plain boxes
## for now (Godot's default look), not the menu book.

const CONTROLS := """[b]Moving and fighting[/b]
WASD or the arrow keys: move · the mouse: face that way
E: talk to the person next to you · right-click someone to talk
Click someone, or Tab, to target · Esc: clear the target
1–9, 0: use the action bar · Shift+1–6 (or < >): switch action bar page
Hold an aimed ability's key to aim, release to cast · Esc or right-click: cancel
R: release to the graveyard when dead · mouse wheel: zoom

[b]Menus[/b] (the menu book)
P Spellbook · T Ability trees · C Character · B Inventory · L Quests
Drag the book's top edge to move it.

[b]Spellbook and trees[/b]
Drag an ability onto the action bar.

[b]Character[/b]
Permanent Mastery unlocks a tree's tiers; Mastery from gear only adds power.

[b]Inventory[/b]
Drag to move or equip · right-click to equip or take off
Shift+click to split a stack · Ctrl+right-click to destroy
Drop a scroll (or your weapon) on the learning slot to learn its ability.

[b]Shop[/b]
Right-click an item in your bag to sell it. Drag the shop by its title to move it.

[b]Escape[/b]
Esc cancels aiming, then closes open menus, then clears your target, then opens
this menu."""

const KEYBINDS := """[b]Keybinds[/b]
Press [b]Keybinds[/b] above, then hover an action bar slot and press the key you want
for it. Esc, or the Keybinds button again, finishes.

Movement, targeting and menu keys are reserved and can't be bound to a slot.
Your keybinds and action bar layout are saved on this computer."""

var hud: Hud
var _log: RichTextLabel
var _shown_lines := -1
var _bind: Button


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
	_bind = _button("Keybinds", func():
		hud.set_bind_mode(not hud.bind_mode)
		visible = false)
	buttons.add_child(_bind)
	buttons.add_child(_button("Leave game", func(): hud.leave_requested.emit()))
	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(tabs)
	_log = _text_tab(tabs, "Log")
	_log.scroll_following = true
	_text_tab(tabs, "Controls").text = CONTROLS
	_text_tab(tabs, "Keybinds").text = KEYBINDS
	visible = false


func _process(_delta: float) -> void:
	if not visible:
		return
	_bind.text = "Done binding" if hud.bind_mode else "Keybinds"
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
