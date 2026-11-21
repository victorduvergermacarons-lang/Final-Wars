class_name CreatureRecolor
extends RefCounted
## Recoloured sprite sheets for creatures whose art asks for it
## (CreatureArtDef.recolor). Each sheet is drawn once through
## view/shaders/creature_recolor.gdshader into an off-screen viewport; the
## viewport's texture is then drawn like any sheet, so recoloured creatures keep
## their place in the world's back-to-front drawing. The viewports live under the
## scene root (they outlast a zone's view), one set per art.

const SHADER := preload("res://view/shaders/creature_recolor.gdshader")
const HOLDER := "CreatureRecolor"

static var _baked := {} # CreatureArtDef -> {anim: Texture2D}


## The recoloured sheets of `art` (anim -> texture), made on first use under
## `root`. They show from the next rendered frame on.
## `look`: one of the art's CreatureArtDef.looks (its own colours, e.g. Stone Skin's
## grey stone) instead of its recolour; "" = the recolour.
static func sheets(art: CreatureArtDef, root: Node, look: StringName = &"") -> Dictionary:
	var bake_key := [art, look]
	if _baked.has(bake_key):
		return _baked[bake_key]
	var holder := root.get_node_or_null(HOLDER)
	if holder == null:
		holder = Node.new()
		holder.name = HOLDER
		root.add_child(holder)
	var out := {}
	for anim in art.sheets:
		var tex: Texture2D = art.sheets[anim]
		var vp := SubViewport.new()
		vp.size = Vector2i(tex.get_width(), tex.get_height())
		vp.transparent_bg = true
		vp.disable_3d = true
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		var rect := TextureRect.new()
		rect.texture = tex
		rect.size = Vector2(vp.size)
		rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var mat := ShaderMaterial.new()
		mat.shader = SHADER
		var params: Dictionary = art.recolor_params() if look == &"" else art.looks.get(look, {})
		for key in params:
			mat.set_shader_parameter(key, params[key])
		rect.material = mat
		vp.add_child(rect)
		holder.add_child(vp)
		out[anim] = vp.get_texture()
	_baked[bake_key] = out
	return out


## Re-renders `art`'s sheets with its current colours (e.g. after tuning them live).
static func refresh(art: CreatureArtDef) -> void:
	for key in _baked.keys():
		if key[0] == art:
			_baked.erase(key)
