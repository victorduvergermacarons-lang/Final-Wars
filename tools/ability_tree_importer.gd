class_name AbilityTreeImporter
extends RefCounted
## Turns the ability design spreadsheet (read by XlsxReader) into the plain data
## file the game loads (content/tree/ability_tree.json), with validation.
## Numbers come from the sheet; behavior is implemented per ability elsewhere
## (content/tree/behaviors/), so re-importing never overwrites it.

const ABILITIES := "Abilities"
const TIERS := "Tiers"
const TREES := "Trees"
const RULES := "Rules & Legend"

## Abilities columns the game needs (all other columns are kept under "extra").
const REQUIRED_COLUMNS := ["ID", "Tree", "Branch", "Tier", "Mastery Required", "Ability", "Role",
	"Prerequisites", "Item Type", "Taught By", "Scales With", "Effect", "Targeting",
	"Targeting Details", "Cooldown (s)", "Mastery on Learn", "Mastery per Use", "Mastery Cap",
	"Mastery Contribution", "Notes"]
## Timing bar columns (optional; see the sheet's "Timing Rules" tab). Absent or
## empty: no timing design.
const TIMING_COLUMNS := ["Timing Status", "Timing Bar (s)", "Timing Zones", "Timing Notes"]
## Timing Status values -> the short form in the data file.
const TIMING_STATUS := {"Manual": "manual", "Generated (AI, not yet confirmed)": "generated",
	"Not implemented": "none", "": "none"}
## Timing Zones kinds -> the data file's zone lists.
const ZONE_KINDS := {"tap": "taps", "crit": "crits", "hold": "holds"}
## Optional numeric columns the designer may add later (decision M3-1).
const OPTIONAL_NUMBERS := {"Base": "base", "Mana Cost": "mana_cost", "Range": "range",
	"Duration": "duration"}
const TARGETING := ["Targeted", "Skillshot", "Ground", "Self"]
const ELEMENTS := ["Fire", "Earth", "Water", "Air"]
## Scales With names -> stat keys used by the game.
const STAT_NAMES := {"Magic Atk": "mag_atk", "Phys Atk": "phys_atk", "Phys Def": "phys_def",
	"Magic Def": "mag_def", "Crit Rate": "crit_rate", "Crit Damage": "crit_dmg", "Speed": "speed",
	"Accuracy": "accuracy", "Evasion": "evasion", "HP": "hp", "Mana": "mana"}


## {"data": Dictionary (empty if there were errors), "errors": [...], "warnings": [...]}.
static func convert(book: Dictionary, source: String = "design/Ability_Tree.xlsx") -> Dictionary:
	var errors: PackedStringArray = []
	var warnings: PackedStringArray = []
	var sheets: Dictionary = book.get("sheets", {})
	for name in [ABILITIES, TIERS, TREES]:
		if not sheets.has(name):
			errors.append("Missing tab \"%s\"" % name)
	if not errors.is_empty():
		return {"data": {}, "errors": errors, "warnings": warnings}

	var tiers := _read_tiers(sheets[TIERS], errors)
	var trees := _read_trees(sheets[TREES], errors)
	var tree_names := {}
	for t in trees:
		tree_names[t.name] = t

	var table: Array = sheets[ABILITIES]
	if table.is_empty():
		errors.append("Abilities tab is empty")
		return {"data": {}, "errors": errors, "warnings": warnings}
	var header: Array = table[0].map(func(h): return String(h).strip_edges())
	var col := {}
	for i in header.size():
		if header[i] != "":
			col[header[i]] = i
	for name in REQUIRED_COLUMNS:
		if not col.has(name):
			errors.append("Abilities tab: missing column \"%s\"" % name)
	if not errors.is_empty():
		return {"data": {}, "errors": errors, "warnings": warnings}

	var abilities: Array = []
	var by_id := {}
	var by_name := {}
	var by_item := {}
	var item_ids := {}
	for r in range(1, table.size()):
		var row: Array = table[r]
		var cell := func(name: String) -> String:
			var i: int = col[name]
			return String(row[i]).strip_edges() if i < row.size() else ""
		var id: String = cell.call("ID")
		if id == "":
			if row.any(func(c): return String(c).strip_edges() != ""):
				errors.append("Abilities row %d: has data but no ID" % (r + 1))
			continue
		var where := "%s (row %d)" % [id, r + 1]
		var a := {"id": id, "row": r + 1}
		a.name = cell.call("Ability")
		a.tree = cell.call("Tree")
		a.branch = cell.call("Branch")
		a.role = cell.call("Role")
		a.item_type = cell.call("Item Type")
		a.taught_by = cell.call("Taught By")
		a.effect = cell.call("Effect")
		a.targeting = cell.call("Targeting")
		a.targeting_details = cell.call("Targeting Details")
		a.mastery_required_text = cell.call("Mastery Required")
		a.prerequisites_text = cell.call("Prerequisites")
		a.scales_with_text = cell.call("Scales With")
		a.mastery_contribution = cell.call("Mastery Contribution")
		a.notes = cell.call("Notes")

		if by_id.has(id):
			errors.append("Duplicate ID %s (rows %d and %d)" % [id, by_id[id].row, r + 1])
			continue
		if a.name == "":
			errors.append("%s: no ability name" % where)
		elif by_name.has(a.name):
			errors.append("%s: duplicate ability name \"%s\" (also %s)" % [where, a.name, by_name[a.name].id])
		if not tree_names.has(a.tree):
			errors.append("%s: unknown tree \"%s\" (not on the Trees tab)" % [where, a.tree])
		elif tree_names[a.tree].item_type != a.item_type:
			errors.append("%s: item type \"%s\" but the %s tree is taught by %s" % [where, a.item_type, a.tree, tree_names[a.tree].item_type])
		var tier_text: String = cell.call("Tier")
		a.tier = _int(tier_text)
		if a.tier < 1 or a.tier > 5:
			errors.append("%s: tier \"%s\" is outside 1–5" % [where, tier_text])
		else:
			a.mastery_required = tiers.get(a.tier, 0)
			var expected := "%s Mastery %d" % [a.tree, a.mastery_required]
			if a.mastery_required_text != "" and a.mastery_required_text != expected:
				warnings.append("%s: Mastery Required says \"%s\", Tiers tab gives \"%s\" (using the Tiers tab)" % [where, a.mastery_required_text, expected])
		if a.taught_by == "":
			errors.append("%s: no item in Taught By" % where)
		elif by_item.has(a.taught_by):
			errors.append("%s: item \"%s\" already teaches %s (each item teaches one ability)" % [where, a.taught_by, by_item[a.taught_by].id])
		else:
			a.item_id = slug(a.taught_by)
			if item_ids.has(a.item_id):
				errors.append("%s: item \"%s\" gets the same id as \"%s\"; rename one" % [where, a.taught_by, item_ids[a.item_id]])
			item_ids[a.item_id] = a.taught_by
			by_item[a.taught_by] = a
		if not TARGETING.has(a.targeting):
			errors.append("%s: targeting \"%s\" isn't one of %s" % [where, a.targeting, ", ".join(TARGETING)])
		a.cooldown = _number(cell.call("Cooldown (s)"), where, "Cooldown (s)", errors)
		a.mastery_on_learn = _number(cell.call("Mastery on Learn"), where, "Mastery on Learn", errors)
		a.mastery_per_use = _number(cell.call("Mastery per Use"), where, "Mastery per Use", errors)
		a.mastery_cap = _number(cell.call("Mastery Cap"), where, "Mastery Cap", errors)
		a.scales_with = _scales_with(a.scales_with_text, tree_names, where, errors)
		var timing := _timing(cell, col, where, errors, warnings)
		if not timing.is_empty():
			a.timing = timing
		var extra := {}
		for h in col:
			if not REQUIRED_COLUMNS.has(h) and not TIMING_COLUMNS.has(h):
				var v: String = cell.call(h)
				if OPTIONAL_NUMBERS.has(h):
					if v != "":
						a[OPTIONAL_NUMBERS[h]] = _number(v, where, h, errors)
				elif v != "":
					extra[h] = v
		if not extra.is_empty():
			a.extra = extra
		abilities.append(a)
		by_id[id] = a
		if a.name != "":
			by_name[a.name] = a

	# Prerequisites need every name, so they're resolved in a second pass.
	for a in abilities:
		a.prerequisites = _prerequisites(a, by_name, tree_names, errors)
	_check_cycles(abilities, by_id, errors)
	for t in trees:
		var n := abilities.filter(func(a): return a.tree == t.name).size()
		if t.has("abilities") and t.abilities != n:
			warnings.append("Trees tab says %s has %d abilities; the Abilities tab has %d" % [t.name, t.abilities, n])

	if not errors.is_empty():
		return {"data": {}, "errors": errors, "warnings": warnings}
	var items: Array = []
	for a in abilities:
		items.append({"id": a.item_id, "name": a.taught_by, "type": a.item_type, "tree": a.tree,
				"tier": a.tier, "ability": a.id})
		a.erase("row")
	var tier_list: Array = []
	for t in tiers:
		tier_list.append({"tier": t, "mastery": tiers[t]})
	var data := {"source": source, "tiers": tier_list, "trees": trees, "abilities": abilities,
			"items": items, "rules": _rules(sheets.get(RULES, []))}
	return {"data": data, "errors": errors, "warnings": warnings}


## Item / id slug: "Scroll of the Fireball" -> "scroll_of_the_fireball".
static func slug(name: String) -> String:
	var out := ""
	for ch in name.to_lower():
		var c := ch.unicode_at(0)
		if ch == "'" or ch == "’":
			continue
		if (c >= 97 and c <= 122) or (c >= 48 and c <= 57):
			out += ch
		elif not out.ends_with("_") and out != "":
			out += "_"
	return out.trim_suffix("_")


static func _read_tiers(table: Array, errors: PackedStringArray) -> Dictionary:
	var out := {}
	for r in range(1, table.size()):
		var row: Array = table[r]
		if row.size() < 2 or not String(row[0]).strip_edges().is_valid_int():
			continue
		out[String(row[0]).to_int()] = int(String(row[1]).to_float())
	for t in range(1, 6):
		if not out.has(t):
			errors.append("Tiers tab: no Mastery Required for tier %d" % t)
	return out


static func _read_trees(table: Array, errors: PackedStringArray) -> Array:
	var out := []
	if table.is_empty():
		errors.append("Trees tab is empty")
		return out
	var header: Array = table[0].map(func(h): return String(h).strip_edges())
	for r in range(1, table.size()):
		var row: Array = table[r]
		var get_cell := func(h: String) -> String:
			var i := header.find(h)
			return String(row[i]).strip_edges() if i >= 0 and i < row.size() else ""
		var name: String = get_cell.call("Tree")
		if name == "" or name == "Total":
			continue
		var t := {"name": name, "item_type": get_cell.call("Item Type"),
				"mastery_stat": get_cell.call("Mastery Stat"), "focus": get_cell.call("Focus"),
				"branches": Array(get_cell.call("Branches").split(",", false)).map(func(b): return b.strip_edges())}
		var n: String = get_cell.call("Abilities")
		if n.is_valid_float():
			t.abilities = int(n.to_float())
		out.append(t)
	if out.is_empty():
		errors.append("Trees tab lists no trees")
	return out


static func _scales_with(text: String, trees: Dictionary, where: String, errors: PackedStringArray) -> Array:
	var out := []
	for part in text.split(",", false):
		var p := part.strip_edges()
		if p.ends_with(" Mastery") and trees.has(p.trim_suffix(" Mastery")):
			out.append({"mastery": p.trim_suffix(" Mastery")})
		elif STAT_NAMES.has(p):
			out.append({"stat": STAT_NAMES[p]})
		else:
			errors.append("%s: Scales With has unknown stat \"%s\"" % [where, p])
	return out


static func _prerequisites(a: Dictionary, by_name: Dictionary, trees: Dictionary, errors: PackedStringArray) -> Dictionary:
	var out := {"abilities": [], "mastery": []}
	var text: String = a.prerequisites_text
	if text == "" or text == "—" or text == "-":
		return out
	var re := RegEx.create_from_string("^(.+?) Mastery (\\d+)$")
	for part in text.split(";", false):
		var p := part.strip_edges()
		if p == "":
			continue
		var m := re.search(p)
		if m != null and (trees.has(m.get_string(1)) or m.get_string(1) == "any element"):
			var tree := m.get_string(1)
			out.mastery.append({"tree": "any_element" if tree == "any element" else tree,
					"amount": m.get_string(2).to_int()})
		elif by_name.has(p):
			var pre: Dictionary = by_name[p]
			if pre.id == a.id:
				errors.append("%s: lists itself as a prerequisite" % a.id)
			out.abilities.append(pre.id)
		else:
			var hint := ""
			for n in by_name:
				if n.to_lower() == p.to_lower():
					hint = " (did you mean \"%s\"?)" % n
			errors.append("%s (%s): unknown prerequisite \"%s\"%s" % [a.id, a.name, p, hint])
	return out


static func _check_cycles(abilities: Array, by_id: Dictionary, errors: PackedStringArray) -> void:
	var state := {} # id -> 1 visiting, 2 done
	var visit := func(id: String, self_ref: Callable) -> bool:
		if state.get(id, 0) == 2:
			return false
		if state.get(id, 0) == 1:
			return true
		state[id] = 1
		for pre in by_id[id].get("prerequisites", {}).get("abilities", []):
			if self_ref.call(pre, self_ref):
				return true
		state[id] = 2
		return false
	for a in abilities:
		if state.get(a.id, 0) == 0 and visit.call(a.id, visit):
			errors.append("Prerequisites loop back on themselves around %s (%s)" % [a.id, a.name])
			return


## The timing design of one row: {"status": "manual"|"generated"|"none",
## "seconds": bar length (0 = no bar), "taps"/"crits"/"holds": [[start, length]…],
## "notes"}; {} when the row has none. Zones are written "Tap 0.35–0.65; Crit
## 0.45–0.55" or "Hold 0.75–2.75" (seconds from the bar's start; dot or comma
## decimals; "-" or "–").
static func _timing(cell: Callable, col: Dictionary, where: String, errors: PackedStringArray,
		warnings: PackedStringArray) -> Dictionary:
	var read := func(name: String) -> String: return cell.call(name) if col.has(name) else ""
	var status_text: String = read.call("Timing Status")
	var bar_text: String = read.call("Timing Bar (s)")
	var zones_text: String = read.call("Timing Zones")
	var notes: String = read.call("Timing Notes")
	if status_text == "" and bar_text == "" and zones_text == "" and notes == "":
		return {}
	if not TIMING_STATUS.has(status_text):
		errors.append("%s: Timing Status \"%s\" isn't one of %s" % [where, status_text,
				", ".join(TIMING_STATUS.keys().filter(func(k): return k != ""))])
		return {}
	var t := {"status": TIMING_STATUS[status_text], "seconds": 0.0, "taps": [], "crits": [], "holds": [],
			"notes": notes}
	var bar := bar_text.replace(",", ".")
	if bar != "" and bar.to_lower() != "none" and bar != "—" and bar != "-":
		t.seconds = _number(bar, where, "Timing Bar (s)", errors)
	var re := RegEx.create_from_string("^(tap|crit|hold)\\s+([0-9]+(?:[.,][0-9]+)?)\\s*[-–—]\\s*([0-9]+(?:[.,][0-9]+)?)\\s*s?$")
	for part in zones_text.replace("\n", ";").split(";", false):
		var text := part.strip_edges()
		if text == "" or text == "—" or text == "-":
			continue
		var m := re.search(text.to_lower())
		if m == null:
			errors.append("%s: Timing Zones \"%s\" isn't like \"Tap 0.35–0.65\", \"Crit 0.45–0.55\" or \"Hold 0.75–2.75\"" % [where, text])
			continue
		var from := m.get_string(2).replace(",", ".").to_float()
		var to := m.get_string(3).replace(",", ".").to_float()
		if to <= from:
			errors.append("%s: Timing Zones \"%s\" ends before it starts" % [where, text])
			continue
		if to > t.seconds + 0.0001:
			errors.append("%s: Timing Zones \"%s\" goes past the %s s bar" % [where, text, t.seconds])
		t[ZONE_KINDS[m.get_string(1)]].append([from, snappedf(to - from, 0.0001)])
	var any_zone: bool = not (t.taps.is_empty() and t.crits.is_empty() and t.holds.is_empty())
	if t.status == "none":
		if t.seconds > 0.0 or any_zone:
			errors.append("%s: Timing Status is \"Not implemented\" but it has a bar or zones" % where)
		return t
	if t.seconds > 0.0 and not any_zone:
		errors.append("%s: a %s s timing bar with no zones" % [where, t.seconds])
	if t.seconds <= 0.0 and any_zone:
		errors.append("%s: Timing Zones but no Timing Bar (s)" % where)
	for h in t.holds:
		var gap: float = t.seconds - (h[0] + h[1])
		if gap < TimingBarDef.HOLD_END_GAP - 0.0001 or gap > TimingBarDef.HOLD_END_GAP_MAX + 0.0001:
			errors.append("%s: a hold zone must end %s–%s s before the bar (this one: %s s)" % [where,
					TimingBarDef.HOLD_END_GAP, TimingBarDef.HOLD_END_GAP_MAX, snappedf(gap, 0.001)])
	for c in t.crits:
		if not t.taps.any(func(z): return c[0] >= z[0] - 0.0001 and c[0] + c[1] <= z[0] + z[1] + 0.0001):
			warnings.append("%s: a Crit zone outside every Tap zone" % where)
	# Several inputs are played in order, one press each: their zones can't overlap.
	var inputs: Array = (t.taps + t.holds).duplicate()
	inputs.sort_custom(func(x, y): return x[0] < y[0])
	for i in range(1, inputs.size()):
		if inputs[i][0] < inputs[i - 1][0] + inputs[i - 1][1] - 0.0001:
			errors.append("%s: input zones overlap (%s–%s and %s–%s); each input needs its own time" % [where,
					inputs[i - 1][0], inputs[i - 1][0] + inputs[i - 1][1], inputs[i][0], inputs[i][0] + inputs[i][1]])
	return t


static func _rules(table: Array) -> Array:
	var out := []
	for row in table:
		var cells: Array = row.map(func(c): return String(c).strip_edges())
		if cells.any(func(c): return c != ""):
			out.append(cells)
	return out


static func _number(text: String, where: String, column: String, errors: PackedStringArray) -> float:
	if text.is_valid_float():
		return text.to_float()
	errors.append("%s: %s \"%s\" isn't a number" % [where, column, text])
	return 0.0


static func _int(text: String) -> int:
	return int(text.to_float()) if text.is_valid_float() and text.to_float() == floorf(text.to_float()) else -1
