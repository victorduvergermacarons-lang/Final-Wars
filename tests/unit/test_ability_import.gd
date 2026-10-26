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
	return [id, tree, "Blasts", tier, "%s Mastery 0" % tree, name, "Damage", prereq, item_type,
			item if item != "" else name + " Scroll", "Fire Mastery, Magic Atk", "Text", targeting,
			"Details", "2", "5", "0.2", "50", "text", ""]


func _errors(rows: Array) -> String:
	return "\n".join(AbilityTreeImporter.convert(_book(rows)).errors)


func test_reads_the_real_sheet() -> void:
	var book := XlsxReader.read(SHEET)
	assert_eq(book.error, "")
	assert_eq(book.order, ["Abilities", "Tiers", "Trees", "Rules & Legend", "Timing Rules"])
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
	assert_eq(result.data.abilities.size(), 145)
	assert_eq(result.data.items.size(), 145)
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
	assert_eq(whip.timing_bar.hold_zones, [Vector2(0.75, 2.0)] as Array[Vector2])
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
	assert_eq(tree.abilities.size(), 145)
	assert_eq(tree.tier_mastery, {1: 0, 2: 150, 3: 350, 4: 600, 5: 900})
	assert_eq(tree.id_of("Flame Dash"), &"F05")
	assert_eq(tree.ability(&"F05").taught_by, "Scroll of Burning Feet")
	assert_eq(tree.ids("Hammer").size(), 20)
	assert_eq(tree.element_trees().size(), 4)
	assert_true(tree.items.has(&"ember_fist_scroll"))
