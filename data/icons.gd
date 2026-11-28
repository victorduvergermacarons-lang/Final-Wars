class_name Icons
extends RefCounted
## Ability and item icons (2026-11-22): where they live, the shared placeholder, and
## how big to draw them. Pixel art, so always at a whole number of screen pixels per
## art pixel (scale_for), centred, never stretched.
##
## - Abilities: AbilityDef.icon, from the Icon column of design/Ability_Tree.xlsx
##   (assets/icons/abilities/<ID>.png, 33x33: a 32 px tile plus a 1 px shadow).
## - Items: ItemDef.icon (assets/icons/items/<item_id>.png, 36x36 with room for glows):
##   the item files set it; scrolls and tree weapons get theirs by id (TreeContent).
## - Missing: the placeholder (assets/icons/placeholder.png), and ContentDB logs one
##   warning per missing id at startup. Except: Sword, Bow and Hammer abilities have no
##   icons yet and keep showing their name, and so do the Legs items in KEEP_NAME.
## New or swapped icons: tools/pull_icons.py (from the art-drafts branch's icons/).

const ABILITY_DIR := "res://assets/icons/abilities/"
const ITEM_DIR := "res://assets/icons/items/"
const PLACEHOLDER_PATH := "res://assets/icons/placeholder.png"
## Trees whose abilities have no icons yet: they keep their name.
const NAME_ONLY_TREES := ["Sword", "Bow", "Hammer"]
## Items with no art yet that keep showing their name (no placeholder).
const KEEP_NAME := [&"acolytes_leggings", &"emberstitch_trousers", &"riverweave_breeches",
	&"quarrymans_trousers", &"breezecloth_leggings"]

static var _placeholder: Texture2D


static func load_icon(path: String) -> Texture2D:
	if path == "":
		return null
	if not path.begins_with("res://"):
		path = "res://" + path
	return load(path) as Texture2D if ResourceLoader.exists(path) else null


static func item_path(id: StringName) -> String:
	return ITEM_DIR + String(id) + ".png"


static func placeholder() -> Texture2D:
	if _placeholder == null:
		_placeholder = load_icon(PLACEHOLDER_PATH)
	return _placeholder


## Whether this ability should have an icon (bending trees yes; weapon arts and
## enemy abilities no).
static func ability_expects_icon(a: AbilityDef) -> bool:
	# Not the parts of tree abilities kept with the enemy abilities (Overheat's burst, Phoenix Kick's landing).
	return a != null and a.tree != "" and not NAME_ONLY_TREES.has(a.tree) and not a.resource_path.begins_with("res://content/abilities/")


## What to draw for an ability: its icon, the placeholder if it should have one,
## else null (draw its name as before).
static func of_ability(a: AbilityDef) -> Texture2D:
	if a == null:
		return null
	if a.icon != null:
		return a.icon
	return placeholder() if ability_expects_icon(a) else null


## What to draw for an item: its icon, else the placeholder, else null for the
## known gaps that keep their name.
static func of_item(it: ItemDef) -> Texture2D:
	if it == null:
		return null
	if it.icon != null:
		return it.icon
	return null if KEEP_NAME.has(it.id) else placeholder()


## Ids with no icon file: items, then abilities that should have one.
static func missing(items: Dictionary, abilities: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = []
	for id in items:
		if items[id].icon == null:
			out.append("item %s" % id)
	for id in abilities:
		if abilities[id].icon == null and ability_expects_icon(abilities[id]):
			out.append("ability %s" % id)
	return out


## The largest whole number of screen pixels per art pixel at which `icon_size` art
## pixels fit in `room` (UI units) on a control whose screen scale is `screen_scale`
## (UI units -> screen pixels: 1 at 1280x720, 1.5 at 1080p). At least 1: a slot too
## small for 1x still gets 1x (it overflows; listed in the Decisions log).
static func screen_scale_for(icon_size: Vector2, room: Vector2, screen_scale: float) -> int:
	var s := maxf(screen_scale, 0.01)
	var k := floori(minf(room.x * s / icon_size.x, room.y * s / icon_size.y) + 0.0001)
	return maxi(k, 1)


## The window's stretch: UI units -> screen pixels for controls at scale 1.
static func window_scale() -> float:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return 1.0
	return tree.root.get_final_transform().get_scale().x


## The control's UI-units -> screen-pixels factor (the window's stretch).
static func screen_scale_of(item: CanvasItem) -> float:
	if item == null or not item.is_inside_tree():
		return 1.0
	return item.get_global_transform_with_canvas().get_scale().x * item.get_viewport().get_final_transform().get_scale().x


## The rect (UI units) to draw `tex` in, centred in `room`, at the largest whole
## screen scale that fits (at most `max_scale`), snapped to whole screen pixels.
static func fit_rect(tex: Texture2D, room: Rect2, screen_scale: float, max_scale: int = 8) -> Rect2:
	var art := Vector2(tex.get_size())
	var k := mini(screen_scale_for(art, room.size, screen_scale), max_scale)
	var s := maxf(screen_scale, 0.01)
	var size := art * k / s
	var pos := room.position + (room.size - size) * 0.5
	pos = (pos * s).round() / s
	return Rect2(pos, size)


## Draws `tex` centred in `room` on `ci` at a whole screen scale; `modulate` tints it.
static func draw_fitted(ci: CanvasItem, tex: Texture2D, room: Rect2, modulate := Color.WHITE,
		max_scale: int = 8, grey := false) -> Rect2:
	if tex == null:
		return Rect2()
	var r := fit_rect(tex, room, screen_scale_of(ci), max_scale)
	ci.draw_texture_rect(greyed(tex) if grey else tex, r, false, modulate)
	return r


static var _grey := {} # texture -> its greyscale copy


## A greyscale copy of `tex` (made once): locked abilities in the tree.
static func greyed(tex: Texture2D) -> Texture2D:
	if _grey.has(tex):
		return _grey[tex]
	var img := tex.get_image()
	if img == null:
		return tex
	img = img.duplicate()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			var v := c.r * 0.3 + c.g * 0.59 + c.b * 0.11
			img.set_pixel(x, y, Color(v, v, v, c.a))
	var out := ImageTexture.create_from_image(img)
	_grey[tex] = out
	return out


## A BBCode image for rich text at 1x in screen pixels (k screen pixels per art
## pixel, k = whole part of the window's stretch, at least 1), sized in UI units.
static func bbcode(tex: Texture2D, screen_scale: float = -1.0) -> String:
	if tex == null:
		return ""
	if screen_scale <= 0.0:
		screen_scale = window_scale()
	var k := maxi(floori(screen_scale + 0.0001), 1)
	var size := Vector2(tex.get_size()) * k / maxf(screen_scale, 0.01)
	return "[img width=%d height=%d]%s[/img]" % [roundi(size.x), roundi(size.y), tex.resource_path]


## A tooltip control: the icon (at 1x in screen pixels) beside `text`, in the
## default tooltip style. Without an icon, a plain label of the text.
static func tooltip(owner: Node, tex: Texture2D, text: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	if tex != null:
		var r := TextureRect.new()
		var s := screen_scale_of(owner) if owner is CanvasItem else window_scale()
		var k := maxi(floori(s + 0.0001), 1)
		r.texture = tex
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.custom_minimum_size = Vector2(tex.get_size()) * k / maxf(s, 0.01)
		r.stretch_mode = TextureRect.STRETCH_SCALE
		r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		r.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(r)
	var l := Label.new()
	l.text = text
	row.add_child(l)
	return row
