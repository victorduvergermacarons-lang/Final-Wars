class_name ElementScreen
extends CanvasLayer
## Picking a new character's element (Earth, Water, Fire, Air), written in the menu
## book: two elements per page, each with its one-line description, the ability it
## starts with (mastered), the one it starts learning and its two key stats. Shown
## by the main menu when a character is created; each player picks for their own
## characters. Emits `chosen` with the StartingElementDef, or `cancelled`.

signal chosen(element: StartingElementDef)
signal cancelled

const BODY_SIZE := 16
const NAME_SIZE := 26

var char_name := ""
var book: BookView
## The "Choose" button of each element, by id (tests press them).
var buttons := {}


func _init(p_char_name: String = "") -> void:
	char_name = p_char_name
	layer = 5


func _ready() -> void:
	book = BookView.new(false)
	book.auto_fit = false
	add_child(book)
	var elements: Array = ContentDB.elements.values()
	elements.sort_custom(func(a, b): return a.order < b.order)
	var pages := [_page(book.left_page), _page(book.right_page)]
	var title := Label.new()
	title.text = "Choose %s's element" % char_name if char_name != "" else "Choose your element"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", UiPalette.LEATHER_DARK)
	pages[0].add_child(title)
	for i in elements.size():
		pages[0 if i < 2 else 1].add_child(_card(elements[i]))
	var back := Button.new()
	back.text = "Back"
	back.pressed.connect(func(): cancelled.emit())
	pages[1].add_child(back)


func _page(page: Control) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.add_theme_constant_override("separation", 6)
	page.add_child(box)
	return box


## An element's card: its name in its colour, what it is, what it starts with.
func _card(e: StartingElementDef) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiPalette.paper_panel(6))
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	panel.add_child(box)
	var head := HBoxContainer.new()
	var name_label := Label.new()
	name_label.text = e.display_name
	name_label.add_theme_font_size_override("font_size", NAME_SIZE)
	name_label.add_theme_color_override("font_color", e.color.darkened(0.25))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name_label)
	var choose := Button.new()
	choose.text = "Choose"
	choose.pressed.connect(func(): chosen.emit(e))
	head.add_child(choose)
	buttons[e.id] = choose
	box.add_child(head)
	for line in lines(e):
		var l := Label.new()
		l.text = line
		l.autowrap_mode = TextServer.AUTOWRAP_WORD
		l.add_theme_font_size_override("font_size", BODY_SIZE)
		box.add_child(l)
	return panel


## The card's text under the name (description, starting ability, learning, stats).
static func lines(e: StartingElementDef) -> PackedStringArray:
	var out := PackedStringArray([e.description])
	var first: AbilityDef = ContentDB.abilities.get(e.mastered_ability_id)
	var next_scroll: ItemDef = ContentDB.items.get(e.learning_scroll_id)
	if first != null:
		out.append("Starts with: %s (mastered)" % first.display_name)
	if next_scroll != null and next_scroll.tree_ability() != null:
		out.append("Learning: %s" % next_scroll.tree_ability().display_name)
	var stats := PackedStringArray()
	for s in e.key_stats:
		stats.append(ItemTooltip.STAT_LABELS[s])
	out.append("Key stats: %s" % " and ".join(stats))
	return out
