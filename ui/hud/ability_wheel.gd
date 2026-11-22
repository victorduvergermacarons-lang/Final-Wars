class_name AbilityWheel
extends Control
## The ability wheel (bottom right, 2026-11-22): the four slots laid out like a
## controller's face buttons, each with its ability, cooldown and button.
##   slot 1 the weapon        = left   (X, left click)
##   slot 2 ranged attacks    = top    (Y, right click)
##   slot 3 dash / defense    = bottom (A, Q)
##   slot 4 the rest          = right  (B, Shift)
## New abilities go to their own slot (Hud.wheel_slot_of, the sheet's Wheel Slot).
## Under it, a reminder of the element button and the timing bar button.

const GAP := 6.0
## Where each slot sits, in slot sizes from the top-left of the wheel.
const PLACES := [Vector2(0, 1), Vector2(1, 0), Vector2(1, 2), Vector2(2, 1)]
const NOTE_HEIGHT := 18.0

var hud: Hud
var slots: Array[SlotButton] = []
var _note: Label
var _shown_revision := -1


func _init(p_hud: Hud) -> void:
	hud = p_hud
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var step := SlotButton.SIZE + Vector2(GAP, GAP)
	custom_minimum_size = SlotButton.SIZE * 3.0 + Vector2(GAP, GAP) * 2.0 + Vector2(0, NOTE_HEIGHT)
	size = custom_minimum_size
	for i in ActionBarModel.SLOT_COUNT:
		var b := SlotButton.new(i, hud)
		b.position = PLACES[i] * step
		b.size = SlotButton.SIZE
		add_child(b)
		slots.append(b)
	_note = Label.new()
	_note.position = Vector2(0, SlotButton.SIZE.y * 3.0 + GAP * 2.0)
	_note.size = Vector2(custom_minimum_size.x, NOTE_HEIGHT)
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_note.add_theme_font_size_override("font_size", 11)
	_note.add_theme_color_override("font_color", Color(0.8, 0.8, 0.85))
	_note.add_theme_color_override("font_outline_color", Color.BLACK)
	_note.add_theme_constant_override("outline_size", 3)
	_note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_note)


func _process(_delta: float) -> void:
	var mode: String = hud.input.mode_name() if hud.input != null else ""
	var hero: Hero = hud.session.local_hero()
	var switch := hero != null and ElementKits.modes(hero.element).size() > 1
	var text := "%s: %s mode (switch)" % [InputActions.hint(&"timing_press"), mode] if switch \
			else "Element %s" % InputActions.hint(&"element_power")
	if text != _note.text:
		_note.text = text
