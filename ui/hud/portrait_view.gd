class_name PortraitView
extends Control
## A speaker's portrait: their picture when one exists (NpcDef.portrait), else a
## placeholder: a frame in their faction's colour with their initials.

const SIZE := Vector2(88, 88)

var texture: Texture2D
var frame_color := Color.GRAY
var initials := "?"


func _init() -> void:
	custom_minimum_size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_npc(def: NpcDef) -> void:
	texture = def.portrait
	frame_color = def.color()
	initials = def.initials()
	queue_redraw()


## The player's own hero (lines spoken by "hero").
func show_hero(hero_name: String, color: Color) -> void:
	texture = null
	frame_color = color
	initials = DialogueLines.initials(hero_name)
	queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	if texture != null:
		draw_texture_rect(texture, r, false)
		draw_rect(r, frame_color, false, 3.0)
		return
	draw_rect(r, frame_color.darkened(0.65))
	draw_rect(r.grow(-4), frame_color.darkened(0.35))
	draw_rect(r, frame_color, false, 4.0)
	var font := ThemeDB.fallback_font
	var fs := 34
	var w := font.get_string_size(initials, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(font, Vector2((size.x - w) * 0.5, size.y * 0.5 + fs * 0.35), initials,
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs, frame_color.lightened(0.55))
