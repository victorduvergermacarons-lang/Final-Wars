extends GutTest
## Spreadsheet import: reading the .xlsx, converting, validating, loading.

const SHEET := "res://design/Ability_Tree.xlsx"
const HEADER := ["ID", "Tree", "Branch", "Tier", "Mastery Required", "Ability", "Role",
	"Prerequisites", "Item Type", "Taught By", "Scales With", "Effect", "Targeting",
	"Targeting Details", "Cooldown (s)", "Mastery on Learn", "Mastery per Use", "Mastery Cap",
	"Mastery Contribution", "Notes"]


## A tiny workbook in the shape XlsxReader returns.
func _book(rows: Array) -> Dictionary:
	var abilities := [HEADER]
	abilities.append_array(rows)
	return {"sheets": {
		"Abilities": abilities,
		"Tiers": [["Tier", "Mastery Required"], ["1", "0"], ["2", "150"], ["3", "350"], ["4", "600"], ["5", "900"]],
		"Trees": [["Tree", "Item Type", "Mastery Stat"], ["Fire", "Scroll", "Fire Mastery"],
				["Air", "Scroll", "Air Mastery"], ["Sword", "Sword", "Sword Mastery"]],
	}, "order": ["Abilities", "Tiers", "Trees"], "error": ""}


func _row(id: String, name: String, tier := "1", prereq := "—", item := "", tree := "Fire",
		item_type := "Scroll", targeting := "Targeted") -> Array:
	var tier_mastery := {"1": 0, "2": 150, "3": 350, "4": 600, "5": 900}
	return [id, tree, "Blasts", tier, "%s Mastery %d" % [tree, tier_mastery.get(tier, 0)], name, "Damage", prereq, item_type,
			item if item != "" else name + " Scroll", "Fire Mastery, Magic Atk", "Text", targeting,
			"Details", "2", "5", "0.2", "50", "text", ""]


func _errors(rows: Array) -> String:
	return "\n".join(AbilityTreeImporter.convert(_book(rows)).errors)


func test_reads_the_real_sheet() -> void:
	var book := XlsxReader.read(SHEET)
	assert_eq(book.error, "")
	assert_eq(book.order, ["Abilities", "Tiers", "Trees", "Rules & Legend", "Timing Rules", "Stance Rework",
			"Stance Changes"])
	var header: Array = book.sheets.Abilities[0]
	assert_eq(header[0], "ID")
	assert_eq(header[5], "Ability")
	assert_eq(book.sheets.Abilities[1][4], "Fire Mastery 0", "formula cells give their saved value")


func test_column_letters() -> void:
	assert_eq(XlsxReader._column_index("A1"), 0)
	assert_eq(XlsxReader._column_index("Z9"), 25)
	assert_eq(XlsxReader._column_index("AB12"), 27)


func test_real_sheet_imports_cleanly() -> void:
	var result := AbilityTreeImporter.convert(XlsxReader.read(SHEET))
	assert_eq(result.errors, PackedStringArray())
	assert_eq(result.data.abilities.size(), 150, "145, +9 new, -4 merged (stance rework)")
	assert_eq(result.data.items.size(), 150)
	assert_eq(result.data.trees.size(), 7)


func test_committed_data_matches_the_sheet() -> void:
	var fresh: Dictionary = AbilityTreeImporter.convert(XlsxReader.read(SHEET)).data
	var saved = JSON.parse_string(FileAccess.get_file_as_string(AbilityTreeData.DEFAULT_PATH))
	assert_eq(JSON.stringify(saved), JSON.stringify(JSON.parse_string(JSON.stringify(fresh))),
			"content/tree/ability_tree.json is out of date: re-run tools/import_ability_tree.gd")


func test_fields_and_prerequisites() -> void:
	var result := AbilityTreeImporter.convert(_book([
		_row("F01", "Fire Punch"),
		_row("F02", "Fire Kick", "2", "Fire Punch; Air Mastery 350"),
		_row("S01", "Edge", "4", "Fire Kick; any element Mastery 350", "Runeblade", "Sword", "Sword", "Self"),
	]))
	assert_eq(result.errors, PackedStringArray())
	var kick: Dictionary = result.data.abilities[1]
	assert_eq(kick.tier, 2)
	assert_eq(kick.mastery_required, 150)
	assert_eq(kick.cooldown, 2.0)
	assert_eq(kick.prerequisites, {"abilities": ["F01"], "mastery": [{"tree": "Air", "amount": 350}]})
	assert_eq(kick.scales_with, [{"mastery": "Fire"}, {"stat": "mag_atk"}])
	var edge: Dictionary = result.data.abilities[2]
	assert_eq(edge.prerequisites.mastery, [{"tree": "any_element", "amount": 350}])
	assert_eq(edge.item_id, "runeblade")
	assert_eq(result.data.items[2], {"id": "runeblade", "name": "Runeblade", "type": "Sword",
			"tree": "Sword", "tier": 4, "ability": "S01"})


func test_each_ability_unlocks_at_its_own_mastery_required() -> void:
	# 2026-11-15: the Mastery Required column decides, not the tier (Water's steps).
	var own := _row("F02", "Fire Kick", "1")
	own[4] = "Fire Mastery 65"
	var empty := _row("F03", "Fire Dart", "2")
	empty[4] = ""
	var result := AbilityTreeImporter.convert(_book([_row("F01", "Fire Punch"), own, empty]))
	assert_eq(result.errors, PackedStringArray())
	assert_eq(result.data.abilities[1].mastery_required, 65, "its own number, though tier 1")
	assert_eq(result.data.abilities[2].mastery_required, 150, "an empty cell falls back to its tier")


func test_mastery_required_is_checked() -> void:
	var other_tree := _row("F01", "A")
	other_tree[4] = "Air Mastery 20"
	assert_string_contains(_errors([other_tree]), "names Air Mastery, but the ability is in the Fire tree")
	var not_a_number := _row("F01", "A")
	not_a_number[4] = "lots"
	assert_string_contains(_errors([not_a_number]), "isn't \"Fire Mastery <number>\"")


func test_a_prerequisite_that_unlocks_later_is_a_warning() -> void:
	var early := _row("F02", "B", "1", "A")
	early[4] = "Fire Mastery 20"
	var late := _row("F01", "A")
	late[4] = "Fire Mastery 65"
	var result := AbilityTreeImporter.convert(_book([late, early]))
	assert_eq(result.errors, PackedStringArray())
	assert_string_contains("\n".join(result.warnings), "F02 (B) needs F01 (A), which unlocks later (Fire Mastery 65 > 20)")


func test_validation_errors() -> void:
	assert_string_contains(_errors([_row("F01", "A"), _row("F01", "B")]), "Duplicate ID F01")
	assert_string_contains(_errors([_row("F01", "Fire Punch"), _row("F02", "B", "2", "fire punch")]),
			"unknown prerequisite \"fire punch\" (did you mean \"Fire Punch\"?)")
	assert_string_contains(_errors([_row("F01", "A", "7")]), "tier \"7\" is outside 1–5")
	assert_string_contains(_errors([_row("F01", "A", "0")]), "outside 1–5")
	var no_item := _row("F01", "A")
	no_item[9] = ""
	assert_string_contains(_errors([no_item]), "no item in Taught By")
	assert_string_contains(_errors([_row("F01", "A", "1", "—", "Same"), _row("F02", "B", "1", "—", "Same")]),
			"already teaches F01")
	assert_string_contains(_errors([_row("F01", "A", "1", "—", "", "Fire", "Sword")]), "taught by Scroll")
	assert_string_contains(_errors([_row("F01", "A", "1", "—", "", "Lava")]), "unknown tree \"Lava\"")
	assert_string_contains(_errors([_row("F01", "A", "1", "—", "", "Fire", "Scroll", "Psychic")]), "targeting \"Psychic\"")
	assert_string_contains(_errors([_row("F01", "A", "1", "B"), _row("F02", "B", "1", "A")]), "loop back")
	var bad_cd := _row("F01", "A")
	bad_cd[14] = "soon"
	assert_string_contains(_errors([bad_cd]), "Cooldown (s) \"soon\" isn't a number")


## A workbook whose Abilities tab has the four timing columns; `timing` per row:
## [status, bar, zones, notes].
func _timed_book(rows: Array) -> Dictionary:
	var book := _book([])
	var table: Array = book.sheets.Abilities
	table[0] = HEADER + AbilityTreeImporter.TIMING_COLUMNS
	for i in rows.size():
		table.append(_row("F%02d" % (i + 1), "Ability %d" % (i + 1)) + rows[i])
	return book


func test_timing_columns() -> void:
	var result := AbilityTreeImporter.convert(_timed_book([
		["Manual", "1", "Tap 0.35–0.65; Crit 0.45-0.55", "mid beat"],
		["Generated (AI, not yet confirmed)", "3,0", "Hold 0,75–2,75", ""],
		["Generated (AI, not yet confirmed)", "none", "", "instant"],
		["Not implemented", "", "", ""],
	]))
	assert_eq(result.errors, PackedStringArray())
	var a: Array = result.data.abilities
	assert_eq(a[0].timing.status, "manual")
	assert_eq(a[0].timing.seconds, 1.0)
	assert_eq(a[0].timing.taps, [[0.35, 0.3]])
	assert_eq(a[0].timing.crits, [[0.45, 0.1]])
	assert_eq(a[1].timing.holds, [[0.75, 2.0]], "comma decimals")
	assert_eq(a[2].timing.seconds, 0.0, "none: no bar")
	assert_eq(a[3].timing.status, "none")
	assert_false(a[0].has("extra"), "timing columns aren't extras")


func test_cast_move_speed_column() -> void:
	var book := _book([_row("F01", "A"), _row("F02", "B"), _row("F03", "C")])
	var table: Array = book.sheets.Abilities
	table[0] = HEADER + ["Cast Move Speed (%)"]
	table[1] = table[1] + ["60"]
	table[2] = table[2] + [""]
	table[3] = table[3] + ["150"]
	var result := AbilityTreeImporter.convert(book)
	assert_string_contains("\n".join(result.errors), "F03 (row 4): Cast Move Speed (%)")
	assert_string_contains("\n".join(result.errors), "isn't between 0 and 100")
	table[3][table[3].size() - 1] = "0"
	result = AbilityTreeImporter.convert(book)
	assert_eq(result.errors, PackedStringArray())
	var a: Array = result.data.abilities
	assert_eq(a[0].cast_move_speed_pct, 60.0)
	assert_false(a[1].has("cast_move_speed_pct"), "empty: the default")
	assert_eq(a[2].cast_move_speed_pct, 0.0, "0: standing still while casting")
	assert_false(a[0].has("extra"), "not an extra column")
	assert_eq(ContentDB.abilities[&"F07"].cast_move_speed, -1.0, "the shipped sheet leaves it to the default")


func test_timing_validation() -> void:
	var errs := func(timing: Array) -> String:
		return "\n".join(AbilityTreeImporter.convert(_timed_book([timing])).errors)
	assert_string_contains(errs.call(["Done", "1", "Tap 0.1–0.2", ""]), "Timing Status \"Done\"")
	assert_string_contains(errs.call(["Manual", "1", "Tap 0.5–1.2", ""]), "goes past the 1")
	assert_string_contains(errs.call(["Manual", "1", "Slide 0.1–0.2", ""]), "isn't like")
	assert_string_contains(errs.call(["Manual", "3", "Hold 0.75–3.0", ""]), "must end 0.2–0.3 s before the bar")
	assert_string_contains(errs.call(["Manual", "3", "Hold 0.5–2.5", ""]), "must end 0.2–0.3 s before the bar")
	assert_string_contains(errs.call(["Manual", "1", "", ""]), "no zones")
	assert_string_contains(errs.call(["Not implemented", "1", "Tap 0.1–0.2", ""]), "Not implemented")
	assert_string_contains(errs.call(["Manual", "4", "Tap 0.2–1.2; Hold 1.0–3.75", ""]), "input zones overlap")
	assert_eq(errs.call(["Manual", "4", "Tap 0.2–0.6; Crit 0.35–0.45; Hold 1.0–3.75", ""]), "", "a tap then a hold")


func test_the_sheet_gives_the_game_its_bars() -> void:
	var slash: AbilityDef = ContentDB.abilities[&"S01"]
	assert_eq(slash.timing_status, "manual")
	assert_eq(slash.timing_bar.seconds, 1.0)
	var whip: AbilityDef = ContentDB.abilities[&"W02"]
	assert_eq(whip.timing_bar.hold_zones, [Vector2(0.45, 2.3)] as Array[Vector2], "0.45–2.75 s since 2026-11-21")
	assert_null(ContentDB.abilities[&"F01"].timing_bar, "Fire Punch is instant since 2026-11-21")
	assert_eq(ContentDB.abilities[&"F05"].timing_status, "generated")
	assert_null(ContentDB.abilities[&"F05"].timing_bar, "a dash: no bar")
	assert_eq(ContentDB.abilities[&"F10"].timing_status, "none")


func test_missing_column_is_reported() -> void:
	var book := _book([])
	book.sheets.Abilities[0] = HEADER.slice(0, 5)
	assert_string_contains("\n".join(AbilityTreeImporter.convert(book).errors), "missing column \"Ability\"")


func test_slugs() -> void:
	assert_eq(AbilityTreeImporter.slug("Scroll of the Fireball"), "scroll_of_the_fireball")
	assert_eq(AbilityTreeImporter.slug("Dragon's Breath Scroll"), "dragons_breath_scroll")
	assert_eq(AbilityTreeImporter.slug("Storm-Fire Scroll"), "storm_fire_scroll")


func test_game_loads_the_trees() -> void:
	var tree := AbilityTreeData.load_file()
	assert_eq(tree.abilities.size(), 150)
	assert_eq(tree.tier_mastery, {1: 0, 2: 100, 3: 225, 4: 375, 5: 550}, "stance rework")
	assert_eq(tree.id_of("Flame Dash"), &"F05")
	assert_eq(tree.ability(&"F05").taught_by, "Scroll of Burning Feet")
	assert_eq(tree.ids("Hammer").size(), 20)
	assert_eq(tree.element_trees().size(), 4)
	assert_true(tree.items.has(&"ember_fist_scroll"))


## A workbook whose one ability row has the Hitbox columns filled with `hitbox`.
func _hitbox_book(hitbox: Array) -> Dictionary:
	var book := _book([_row("F01", "Punch") + hitbox])
	book.sheets.Abilities[0] = HEADER + AbilityTreeImporter.HITBOX_COLUMNS
	return book


func test_hitbox_columns_are_read() -> void:
	var data: Dictionary = AbilityTreeImporter.convert(_hitbox_book(["Cone", "1.4", "100", "", "", "", "", ""])).data
	assert_eq(data.abilities[0].hitbox, {"shape": "Cone", "range": 1.4, "angle": 100.0, "pierce": false})
	data = AbilityTreeImporter.convert(_hitbox_book(["Projectile", "4.5", "", "", "", "16", "0.25", "Yes"])).data
	var h := HitboxDef.from_data(data.abilities[0].hitbox)
	assert_eq(h.shape, HitboxDef.Shape.PROJECTILE)
	assert_eq(h.speed, 16.0)
	assert_true(h.pierce)


func test_hitbox_validation() -> void:
	var errs := func(hitbox: Array) -> String:
		return "\n".join(AbilityTreeImporter.convert(_hitbox_book(hitbox)).errors)
	assert_string_contains(errs.call(["Square", "1", "", "", "", "", "", ""]), "Hitbox Shape \"Square\"")
	assert_string_contains(errs.call(["Cone", "1.4", "", "", "", "", "", ""]), "needs Hitbox Angle")
	assert_string_contains(errs.call(["Circle", "-2", "", "", "1", "", "", ""]), "Hitbox Range is negative")
	assert_string_contains(errs.call(["", "3", "", "", "", "", "", ""]), "no Hitbox Shape")
	assert_string_contains(errs.call(["Line", "3", "", "1", "", "", "", "Maybe"]), "Pierce \"Maybe\"")
	assert_eq(errs.call(["None", "", "", "", "", "", "", ""]), "")


func test_every_ability_in_the_sheet_has_a_hitbox() -> void:
	for id in ContentDB.abilities:
		var a: AbilityDef = ContentDB.abilities[id]
		if ContentDB.tree.abilities.has(id):
			assert_not_null(a.sheet_hitbox, "%s has a hitbox in the sheet" % id)
	assert_eq(ContentDB.abilities[&"S01"].sheet_hitbox.shape, HitboxDef.Shape.CONE)
	assert_eq(ContentDB.abilities[&"F08"].sheet_hitbox.shape, HitboxDef.Shape.TILES, "burning ground stays on the grid")
	assert_true(ContentDB.abilities[&"F08"].sheet_hitbox.on_grid())


# --- Stance rework (2026-11-23) -----------------------------------------------

## A workbook with the stance columns: `rows` are [id, name, tier, mastery text, key,
## step, prereq, cooldown] (Fire scrolls).
func _stance_book(rows: Array, step_points := true) -> Dictionary:
	var header := HEADER + ["Stance", AbilityTreeImporter.KEY_COLUMN, AbilityTreeImporter.STEP_COLUMN]
	var table := [header]
	for r in rows:
		var row := _row(r[0], r[1], str(r[2]), r[6] if r.size() > 6 else "—")
		row[4] = r[3]
		if r.size() > 7:
			row[14] = str(r[7])
		var key: String = r[4]
		var stance := key.left(1) if key != "" and key.left(1).is_valid_int() else ""
		table.append(row + [stance, key, str(r[5])])
	var book := _book([])
	book.sheets.Abilities = table
	book.sheets.Tiers = [["Tier", "Mastery Required", "Meaning", "Points per unlock step"] if step_points
			else ["Tier", "Mastery Required"], ["1", "0", "", "25"], ["2", "100", "", "30"], ["3", "225", "", "35"],
			["4", "375", "", "40"], ["5", "550", "", "50"]]
	return book


func _stance_errors(rows: Array, step_points := true) -> String:
	return "\n".join(AbilityTreeImporter.convert(_stance_book(rows, step_points)).errors)


func test_unlock_steps_must_match_their_tier() -> void:
	var ok := AbilityTreeImporter.convert(_stance_book([
		["F01", "Punch", 1, "Fire Mastery 0", "1 → 1", 0],
		["F02", "Kick", 1, "Fire Mastery 50", "1 → 2", 2],
		["F09", "Combo", 2, "Fire Mastery 130", "2 → 1", 1, "Kick"],
	]))
	assert_false(" ".join(ok.errors).contains("isn't tier"), "0 + 2 × 25 and 100 + 1 × 30 match: %s" % [ok.errors])
	assert_string_contains(_stance_errors([["F02", "Kick", 1, "Fire Mastery 40", "1 → 2", 2]]),
			"Mastery Required 40 isn't tier 1's base 0 + step 2 × 25 = 50")
	assert_string_contains(_stance_errors([["F02", "Kick", 1, "Fire Mastery 50", "1 → 2", 2]], false),
			"no Points per unlock step for tier 1")


func test_keys_stances_and_branches() -> void:
	var data: Dictionary = AbilityTreeImporter.convert(_stance_book([
		["F01", "Punch", 1, "Fire Mastery 0", "1 (casts on entering stance 1)", 0],
		["F02", "Kick", 1, "Fire Mastery 25", "1 → 3", 1],
	])).data
	assert_true(data.is_empty(), "an incomplete tree doesn't import")
	var errs := _stance_errors([
		["F01", "Punch", 1, "Fire Mastery 0", "1 (casts on entering stance 1)", 0],
		["F02", "Kick", 1, "Fire Mastery 25", "1 → 3", 1],
		["F03", "Dart", 1, "Fire Mastery 25", "1 → 3", 1],
		["F04", "Breath", 2, "Fire Mastery 100", "1 → 4", 0],
		["F05", "Dash", 1, "Fire Mastery 0", "1 → 5", 0],
		["F06", "Whip", 1, "Fire Mastery 0", "sideways", 0],
		["F07", "Ball", 1, "Fire Mastery 0", "", 0],
	])
	assert_string_contains(errs, "F02 and F03 both sit in Fire stance 1 → 3")
	assert_string_contains(errs, "F04 (row 5): stance 1 but tier 2")
	assert_string_contains(errs, "branch 5 isn't 1-4")
	assert_string_contains(errs, "Key \"sideways\" isn't")
	assert_string_contains(errs, "F07 (row 8): a bending ability needs a Key")
	assert_string_contains(errs, "Fire stance 2 → 1 has no ability")
	assert_false(errs.contains("Fire stance 1 → 3 has no ability"))


func test_passives_and_upgrades() -> void:
	var errs := _stance_errors([
		["F10", "Rain", 5, "Fire Mastery 550", "5 → 1", 0],
		["F20", "Blue", 2, "Fire Mastery 200 / 400 / 600", "Passive", "", "—", 0],
		["F21", "Hot", 2, "Fire Mastery 400 / 300", "Passive", "", "—", 5],
		["F22", "Rebirth", 5, "Fire Mastery 800", "Passive upgrade", "", "Rain", 0],
		["F23", "Lost", 5, "Fire Mastery 800", "Passive upgrade", "", "—", 0],
	])
	assert_false(errs.contains("F20"), "a passive's levels: " + errs)
	assert_string_contains(errs, "F21 (row 4): Mastery Required levels \"400 / 300\" must go up")
	assert_string_contains(errs, "F21 (Hot): a passive has no cooldown")
	assert_string_contains(errs, "F23 (Lost): a passive upgrade needs the ability it upgrades")
	assert_false(errs.contains("F22"))


func test_the_real_sheet_has_stances_passives_and_upgrades() -> void:
	var tree := AbilityTreeData.load_file()
	var a := tree.ability(&"W01")
	assert_eq([int(a.stance), int(a.branch_key)], [1, 1], "Healing Touch: 1 → 1")
	assert_eq([int(tree.ability(&"W19").stance), int(tree.ability(&"W19").branch_key)], [4, 4], "Bloodbending: 4 → 4")
	assert_true(tree.ability(&"F01").get("entry_cast", false), "Fire Punch enters Fire 1")
	assert_true(tree.ability(&"E04").get("entry_cast", false), "Seismic Stomp enters Earth 1")
	assert_eq(int(tree.ability(&"W20").stance), 5, "Octopus Form enters Water 5")
	assert_true(tree.ability(&"F20").get("passive", false), "Blue Fire is passive")
	assert_eq(tree.ability(&"F20").mastery_levels.map(func(v): return int(v)), [200, 400, 600])
	assert_eq(tree.ability(&"W23").upgrades, "W17", "Tidal Resurgence upgrades Healing Rain")
	assert_eq(tree.ability(&"A21").upgrades, "A15", "Eye of the Storm upgrades Hurricane")
	assert_eq(int(tree.ability(&"F06").mastery_required), 260, "225 + 1 × 35")
	assert_eq(int(tree.ability(&"S04").mastery_required), 50, "weapons too: 0 + 2 × 25")
	for id in [&"F13", &"E10", &"E12", &"A08"]:
		assert_false(tree.abilities.has(id), "%s was merged away" % id)


func test_removed_ids_and_hybrids() -> void:
	var errs := _stance_errors([
		["F13", "Heat Wave", 1, "Fire Mastery 0", "1 → 1", 0],
		["F02", "Kick", 1, "Fire Mastery 0", "1 → 2", 0, "Air Mastery 350"],
	])
	assert_string_contains(errs, "F13 (row 2): removed in the stance rework, Heat Wave (merged into Breath of Fire)")
	var warnings: PackedStringArray = AbilityTreeImporter.convert(_stance_book([
		["F02", "Kick", 1, "Fire Mastery 0", "1 → 2", 0, "Air Mastery 350"]])).warnings
	assert_string_contains(" ".join(warnings), "needs Air Mastery 350; hybrid requirements are 225")
