class_name IconView
extends Control
## An ability or item icon drawn centred in this control at the largest whole number
## of screen pixels per art pixel that fits (Icons.draw_fitted): never stretched.
## Mouse input passes through to what's under it.

var texture: Texture2D:
	set(t):
		texture = t
		queue_redraw()
var tint := Color.WHITE:
	set(c):
		tint = c
		queue_redraw()
var grey := false


func _init(p_texture: Texture2D = null, room := Vector2(36, 36)) -> void:
	texture = p_texture
	custom_minimum_size = room
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_vertical = Control.SIZE_SHRINK_CENTER


func _draw() -> void:
	Icons.draw_fitted(self, texture, Rect2(Vector2.ZERO, size), tint, 8, grey)


## Puts an icon on the left of `button` (its text moves over): an IconView child,
## and the button's styleboxes copied with room on their left.
static func add_to_button(button: Button, tex: Texture2D, room := Vector2(40, 40)) -> IconView:
	if tex == null:
		return null
	var view := IconView.new(tex, room)
	button.add_child(view)
	button.custom_minimum_size.y = maxf(button.custom_minimum_size.y, room.y + 4.0)
	var fit := func():
		for state in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
			var box: StyleBox = button.get_theme_stylebox(state)
			if box == null:
				continue
			box = box.duplicate()
			box.content_margin_left = room.x + 8.0
			button.add_theme_stylebox_override(state, box)
		view.position = Vector2(4.0, (button.size.y - room.y) * 0.5).round()
	button.ready.connect(fit, CONNECT_ONE_SHOT)
	button.resized.connect(func(): view.position = Vector2(4.0, (button.size.y - room.y) * 0.5).round())
	return view
