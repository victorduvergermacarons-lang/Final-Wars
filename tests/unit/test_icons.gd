extends GutTest
## Icons (2026-11-22): every Fire, Earth, Water and Air ability and every item has an
## icon file that exists, imported as pixel art; the known gaps are listed here.
## Drawing is always at a whole number of screen pixels per art pixel.

## Items with no art yet. The five Legs items: the sheets have no trousers (they keep
## showing their name). The 20 element set pieces (2026-11-20) were made after the
## icon set (they show the placeholder).
const KNOWN_GAPS := [
	&"acolytes_leggings", &"emberstitch_trousers", &"riverweave_breeches", &"quarrymans_trousers",
	&"breezecloth_leggings",
	&"quarrymans_gloves", &"quarrymans_hood", &"quarrymans_boots", &"granite_ring", &"bedrock_charm",
	&"riverweave_gloves", &"riverweave_hood", &"riverweave_sandals", &"tidestone_ring", &"pearl_pendant",
	&"emberstitch_gloves", &"emberstitch_cap", &"emberstitch_boots", &"cinder_ring", &"ashglass_pendant",
	&"breezecloth_wraps", &"breezecloth_hood", &"breezecloth_shoes", &"gale_ring", &"feather_charm",
]
const ELEMENTS := ["Fire", "Earth", "Water", "Air"]


func _bending() -> Array:
	return ContentDB.abilities.values().filter(func(a): return ELEMENTS.has(a.tree))


func test_every_bending_ability_has_its_icon() -> void:
	var abilities := _bending()
	assert_eq(abilities.size(), 85, "F01-F21, E01-E20, W01-W23, A01-A21")
	for a: AbilityDef in abilities:
		var path := "%s%s.png" % [Icons.ABILITY_DIR, a.id]
		assert_true(ResourceLoader.exists(path), "%s has %s" % [a.id, path])
		assert_not_null(a.icon, "%s carries its icon (the sheet's Icon column)" % a.id)
		if a.icon != null:
			assert_eq(a.icon.resource_path, path, "%s: by its ID" % a.id)
			assert_eq(Vector2i(a.icon.get_size()), Vector2i(33, 33), "%s: 32 px plus a 1 px shadow" % a.id)


func test_weapon_abilities_keep_their_name() -> void:
	for id in [&"S01", &"S04", &"B01", &"B02", &"H01", &"H02"]:
		var a: AbilityDef = ContentDB.abilities[id]
		assert_null(a.icon, "%s has no icon yet" % id)
		assert_null(Icons.of_ability(a), "%s: no placeholder, its name shows" % id)


func test_every_item_has_its_icon_but_the_known_gaps() -> void:
	assert_gt(ContentDB.items.size(), 190)
	for id in ContentDB.items:
		var it: ItemDef = ContentDB.items[id]
		var path := Icons.item_path(id)
		if KNOWN_GAPS.has(id):
			assert_false(ResourceLoader.exists(path), "%s is listed as a gap but has art now: take it off the list" % id)
			continue
		assert_true(ResourceLoader.exists(path), "%s has %s" % [id, path])
		assert_not_null(it.icon, "%s carries its icon" % id)
		if it.icon != null:
			assert_eq(it.icon.resource_path, path, "%s: by its id" % id)
			assert_eq(Vector2i(it.icon.get_size()), Vector2i(36, 36), "%s: 36x36" % id)


func test_retired_items_and_every_scroll_have_their_own_icon() -> void:
	for id in [&"sword", &"staff", &"hunting_bow", &"greataxe", &"shield", &"holy_charm"]:
		assert_not_null(ContentDB.items[id].icon, "retired %s" % id)
	var scrolls := ContentDB.items.values().filter(func(i): return i.is_scroll)
	assert_eq(scrolls.size(), 85)
	var paths := {}
	for it in scrolls:
		paths[it.icon.resource_path] = true
	assert_eq(paths.size(), 85, "each scroll its own icon, not one shared scroll")


func test_missing_icons_fall_back_to_the_placeholder() -> void:
	assert_true(ResourceLoader.exists(Icons.PLACEHOLDER_PATH))
	var it := ItemDef.new()
	it.id = &"no_such_item"
	assert_eq(Icons.of_item(it), Icons.placeholder(), "an item without art: the placeholder")
	assert_null(Icons.of_item(ContentDB.items[&"acolytes_leggings"]), "the Legs gaps keep their name")
	assert_eq(Icons.of_item(ContentDB.items[&"cinder_ring"]), Icons.placeholder())
	var a := AbilityDef.new()
	a.tree = "Fire"
	assert_eq(Icons.of_ability(a), Icons.placeholder(), "a bending ability without art: the placeholder")
	assert_null(Icons.load_icon("assets/icons/items/not_there.png"), "a missing file is null, never a crash")
	var gaps := Icons.missing(ContentDB.items, ContentDB.abilities)
	assert_eq(gaps.size(), KNOWN_GAPS.size(), "startup warns once per missing id: %s" % ", ".join(gaps))


func test_icons_import_as_pixel_art() -> void:
	var files := _pngs("res://assets/icons/abilities/") + _pngs("res://assets/icons/items/") + [Icons.PLACEHOLDER_PATH]
	assert_eq(files.size(), 85 + 172 + 1)
	for path in files:
		var cfg := ConfigFile.new()
		assert_eq(cfg.load(path + ".import"), OK, "%s has its import settings" % path)
		assert_eq(cfg.get_value("params", "compress/mode"), 0, "%s: lossless" % path)
		assert_false(cfg.get_value("params", "mipmaps/generate"), "%s: no mipmaps" % path)
		assert_false(cfg.get_value("params", "process/fix_alpha_border"), "%s: no fix-alpha-border" % path)
	assert_eq(ProjectSettings.get_setting("rendering/textures/canvas_textures/default_texture_filter"), 0,
			"nearest filtering by default")


func test_scale_is_a_whole_number_of_screen_pixels() -> void:
	var icon := Vector2(33, 33)
	assert_eq(Icons.screen_scale_for(icon, Vector2(56, 56), 1.0), 1, "action bar at 720p: 1x")
	assert_eq(Icons.screen_scale_for(icon, Vector2(56, 56), 1.5), 2, "action bar at 1080p: 2x")
	assert_eq(Icons.screen_scale_for(Vector2(36, 36), Vector2(64, 64), 1.0), 1)
	assert_eq(Icons.screen_scale_for(Vector2(36, 36), Vector2(20, 20), 1.0), 1, "never under 1x")
	var tex: Texture2D = ContentDB.abilities[&"F07"].icon
	for scale in [1.0, 1.5, 2.0, 0.75]:
		var r := Icons.fit_rect(tex, Rect2(3, 3, 56, 56), scale)
		var px: float = r.size.x * scale / 33.0
		assert_almost_eq(px, roundf(px), 0.001, "x%s: whole screen pixels per art pixel (%s)" % [scale, px])
		assert_almost_eq(r.size.x, r.size.y, 0.001, "never stretched")
		assert_almost_eq(r.get_center().x, 31.0, 0.5 / scale + 0.001, "centred")


func test_rich_text_icons_are_whole_pixels() -> void:
	var tex: Texture2D = ContentDB.items[&"sword"].icon
	assert_string_contains(Icons.bbcode(tex, 1.0), "width=36 height=36")
	# 1080p: 1 screen pixel per art pixel; a 2x window: 2 screen pixels.
	assert_string_contains(Icons.bbcode(tex, 1.5), "width=24 height=24")
	assert_string_contains(Icons.bbcode(tex, 2.0), "width=36 height=36")
	assert_eq(Icons.bbcode(null), "")


static func _pngs(dir: String) -> Array:
	var out := []
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".png"):
			out.append(dir + f)
	return out
