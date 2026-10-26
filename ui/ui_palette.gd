class_name UiPalette
extends RefCounted
## Colours and theme for menus written on paper: the menu book's pages, tooltips,
## the quest tracker and the dialogue box. Paper and leather colours are taken
## from the book art (assets/ui/menu_book.png); text is dark ink so it reads on
## cream. The HUD over the world (unit frames, action bar, message log) keeps
## Godot's dark default look.

const PAPER := Color("f6e4ce")
const PAPER_SHADE := Color("e9c4a0")
const PAPER_EDGE := Color("d9b89b")
const INK := Color("341c27")
## Hints and secondary text (was light grey on dark).
const INK_SOFT := Color("7a5c4f")
const LEATHER := Color("886039")
const LEATHER_LIGHT := Color("a8784a")
const LEATHER_DARK := Color("5f2c2c")

## BBCode colours that read on paper (ItemTooltip, QuestText…).
const GREEN := "#2e7d32"
const RED := "#b3261e"
const GREY := "#7a5c4f"
const GOLD := "#94600a"
const BLUE := "#1f5fa8"

## Text size on paper (Godot's default is 16; the book's text was hard to read).
const FONT_SIZE := 20

static var _paper_theme: Theme


## The theme for anything drawn on paper: window boxes are see-through (the page
## shows), text is ink, buttons are leather, fields and tooltips are paper.
static func paper_theme() -> Theme:
	if _paper_theme != null:
		return _paper_theme
	var t := Theme.new()
	t.default_font_size = FONT_SIZE
	t.set_color("font_color", "Label", INK)
	t.set_color("default_color", "RichTextLabel", INK)
	t.set_stylebox("panel", "PanelContainer", StyleBoxEmpty.new())

	for type in ["Button", "OptionButton", "CheckBox"]:
		t.set_stylebox("normal", type, _box(LEATHER, LEATHER_DARK))
		t.set_stylebox("hover", type, _box(LEATHER_LIGHT, LEATHER_DARK))
		t.set_stylebox("pressed", type, _box(LEATHER_DARK, LEATHER_DARK))
		t.set_stylebox("disabled", type, _box(Color(LEATHER, 0.45), Color(LEATHER_DARK, 0.45)))
		t.set_stylebox("focus", type, StyleBoxEmpty.new())
		t.set_color("font_color", type, PAPER)
		t.set_color("font_hover_color", type, Color.WHITE)
		t.set_color("font_pressed_color", type, PAPER)
		t.set_color("font_focus_color", type, PAPER)
		t.set_color("font_disabled_color", type, Color(PAPER, 0.6))

	var field := _box(PAPER_SHADE, LEATHER)
	t.set_stylebox("normal", "LineEdit", field)
	t.set_stylebox("focus", "LineEdit", _box(PAPER_SHADE, LEATHER_DARK, 2))
	t.set_color("font_color", "LineEdit", INK)
	t.set_color("font_placeholder_color", "LineEdit", Color(INK_SOFT, 0.8))
	t.set_color("caret_color", "LineEdit", INK)

	t.set_stylebox("panel", "TooltipPanel", _box(PAPER, LEATHER, 2, 6))
	t.set_color("font_color", "TooltipLabel", INK)
	t.set_font_size("font_size", "TooltipLabel", ItemTooltip.TOOLTIP_FONT_SIZE)
	t.set_stylebox("panel", "PopupMenu", _box(PAPER, LEATHER, 2, 4))
	t.set_stylebox("hover", "PopupMenu", _box(PAPER_SHADE, PAPER_SHADE))
	t.set_color("font_color", "PopupMenu", INK)
	t.set_color("font_hover_color", "PopupMenu", INK)

	t.set_stylebox("tab_selected", "TabBar", _box(LEATHER, LEATHER_DARK))
	t.set_stylebox("tab_hovered", "TabBar", _box(LEATHER_LIGHT, LEATHER_DARK))
	t.set_stylebox("tab_unselected", "TabBar", _box(PAPER_SHADE, LEATHER))
	t.set_stylebox("tab_focus", "TabBar", StyleBoxEmpty.new())
	t.set_color("font_selected_color", "TabBar", PAPER)
	t.set_color("font_hovered_color", "TabBar", Color.WHITE)
	t.set_color("font_unselected_color", "TabBar", INK)

	var line := StyleBoxLine.new()
	line.color = Color(LEATHER, 0.6)
	line.thickness = 1
	t.set_stylebox("separator", "HSeparator", line)
	_paper_theme = t
	return t


## A loose paper sheet (dialogue box, quest tracker): paper with a leather edge.
static func paper_panel(margin: float = 8.0) -> StyleBoxFlat:
	return _box(PAPER, LEATHER, 2, margin)


static func _box(bg: Color, border: Color, width: int = 1, margin: float = 6.0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(2)
	s.content_margin_left = margin
	s.content_margin_right = margin
	s.content_margin_top = margin * 0.5
	s.content_margin_bottom = margin * 0.5
	return s
