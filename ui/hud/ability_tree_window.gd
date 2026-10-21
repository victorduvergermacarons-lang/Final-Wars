class_name AbilityTreeWindow
extends BookSpread
## The ability trees (T), across the menu book: one tab per tree. Tiers go left
## to right, one column each: tiers 1–3 on the left page, 4 and 5 on the right,
## each headed by the Mastery it needs. Abilities show their state (mastered,
## learning, learnable, locked, not in the game yet), AP and how much Mastery
## they have given toward their cap, with lines from their prerequisites. Usable
## abilities can be dragged onto the action bar.

## Space between nodes; tier columns on the left page (the rest go right).
const GAP := Vector2(10, 10)
const LEFT_TIERS := 3
const TIER_HEADER_H := 44.0

enum State { MASTERED, LEARNING, LEARNABLE, LOCKED, NOT_IN_GAME }

const STATE_COLORS := {
	State.MASTERED: Color(0.85, 0.7, 0.2),
	State.LEARNING: Color(0.3, 0.65, 1.0),
	State.LEARNABLE: Color(0.85, 0.85, 0.85),
	State.LOCKED: Color(0.4, 0.4, 0.45),
	State.NOT_IN_GAME: Color(0.25, 0.25, 0.28),
}
const STATE_NAMES := {
	State.MASTERED: "Mastered", State.LEARNING: "Learning", State.LEARNABLE: "Can learn",
	State.LOCKED: "Locked", State.NOT_IN_GAME: "Not in the game yet",
}

var hud: Hud
var tree_name := "Fire"
var _tabs: TabBar
var _header: Label
var _canvas: _Canvas
var _shown_key := ""


func _init(p_hud: Hud) -> void:
	super()
	hud = p_hud
	left.add_child(BookSpread.title("Ability Trees"))
	_tabs = TabBar.new()
	for t in Mastery.TREES:
		_tabs.add_tab(t)
	_tabs.tab_changed.connect(func(i): show_tree(Mastery.TREES[i]))
	# All seven trees show (no scroll arrows): a little smaller than page text.
	_tabs.clip_tabs = false
	_tabs.add_theme_font_size_override("font_size", 17)
	left.add_child(_tabs)
	_header = BookSpread.note("")
	_header.add_theme_color_override("font_color", UiPalette.INK)
	right.add_child(_header)
	set_footnote("Drag a usable ability onto the action bar.")
	_canvas = _Canvas.new(self)
	add_child(_canvas)


## The pages' headings go on top; the tree fills both pages below them, down to
## the footnote.
func lay_out(left_rect: Rect2, right_rect: Rect2) -> void:
	super.lay_out(left_rect, right_rect)
	var top := roundf(maxf(left.position.y + left.get_combined_minimum_size().y,
			right.position.y + right.get_combined_minimum_size().y) + 10.0)
	var bottom := right.position.y + right.size.y
	var geometry := [Rect2(left_rect.position.x, top, left_rect.size.x, bottom - top),
			Rect2(right_rect.position.x, top, right_rect.size.x, bottom - top)]
	if geometry != _canvas.pages:
		_canvas.pages = geometry
		_shown_key = "" # rebuild at the new size


func show_tree(t: String) -> void:
	tree_name = t
	_tabs.current_tab = Mastery.TREES.find(t)
	_shown_key = ""


func _process(_delta: float) -> void:
	if not visible:
		return
	var hero: Hero = hud.session.local_hero()
	if hero == null:
		return
	var now: float = hud.session.now()
	var permanent := Mastery.permanent(hero, tree_name)
	var gear := Mastery.total(hero, tree_name, now) - permanent
	var key := "%s|%s|%s|%s|%s|%.1f|%.1f" % [tree_name, hero.mastered.keys(), hero.ap, hero.mastery_contrib,
			hero.active_learning_item().id if hero.active_learning_item() != null else "", permanent, gear]
	if key == _shown_key:
		return
	_shown_key = key
	# Each tier column shows what it needs; this is what you have.
	_header.text = "%s Mastery: %d%s" % [tree_name, floori(permanent),
			"  (+%d from gear, power only)" % floori(gear) if gear >= 1.0 else ""]
	_canvas.rebuild(hero)


## How an ability looks for this hero.
static func state_of(hero: Hero, ability: AbilityDef) -> State:
	if not ability.implemented:
		return State.NOT_IN_GAME
	if hero.is_mastered(ability.id):
		return State.MASTERED
	var learning := hero.active_learning_item()
	if learning != null and learning.tree_ability() == ability:
		return State.LEARNING
	if TreeRules.can_learn(hero, ability) == "":
		return State.LEARNABLE
	return State.LOCKED


## Why a locked ability is locked, for its tooltip.
static func lock_reason(hero: Hero, ability: AbilityDef) -> String:
	match TreeRules.can_learn(hero, ability):
		"mastery_too_low":
			var need := int(ability.sheet.get("mastery_required", 0))
			var have := Mastery.permanent(hero, ability.tree)
			if have + 0.0001 < need:
				return "Needs %s Mastery %d (you have %d)." % [ability.tree, need, floori(have)]
			return "Needs: %s." % ability.sheet.get("prerequisites_text", "")
		"prerequisite":
			return "Needs: %s." % ability.sheet.get("prerequisites_text", "")
		"":
			return ""
		var other:
			return "Locked (%s)." % other.replace("_", " ")


static func node_text(hero: Hero, ability: AbilityDef) -> String:
	var lines := [ability.display_name]
	var given := TreeRules.contribution(hero, ability)
	var progress: PackedStringArray = []
	if not hero.is_mastered(ability.id) and (hero.ap.get(ability.id, 0) > 0 or state_of(hero, ability) == State.LEARNING):
		progress.append("AP %d/%d" % [hero.ap.get(ability.id, 0), ability.ap_to_master])
	# Two lines fit a node: while AP shows, the Mastery count stays in the tooltip.
	if given.y > 0.0 and progress.is_empty():
		progress.append("Mastery %d/%d" % [floori(given.x), int(given.y)])
	lines.append(" · ".join(progress) if not progress.is_empty() else STATE_NAMES[state_of(hero, ability)])
	return "\n".join(lines)


class _Canvas:
	extends Control
	var window: AbilityTreeWindow
	## Where the tree may go on each page, in the window's coordinates.
	var pages: Array = [Rect2(), Rect2()]
	var _nodes := {} # ability id -> _Node
	var _lines: Array = [] # [from Vector2, to Vector2, Color]

	func _init(p_window: AbilityTreeWindow) -> void:
		window = p_window
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func rebuild(hero: Hero) -> void:
		for c in get_children():
			c.queue_free()
		_nodes.clear()
		_lines.clear()
		var data: AbilityTreeData = ContentDB.tree
		var by_tier := {}
		var tallest := 1
		for id in data.ids(window.tree_name):
			var row: Dictionary = data.ability(id)
			if not by_tier.has(row.tier):
				by_tier[row.tier] = []
			by_tier[row.tier].append(id)
			tallest = maxi(tallest, by_tier[row.tier].size())
		# One column per tier: tiers 1..LEFT_TIERS share the left page, the rest the
		# right page. Every node the same size; the abilities of a tier go down.
		var lp: Rect2 = pages[0]
		var rp: Rect2 = pages[1]
		var col_l := lp.size.x / LEFT_TIERS
		var col_r := rp.size.x / (5 - LEFT_TIERS)
		var row_h := (minf(lp.size.y, rp.size.y) - TIER_HEADER_H) / tallest
		var node_size := Vector2(maxf(minf(col_l, col_r) - GAP.x, 40.0), maxf(row_h - GAP.y, 30.0)).floor()
		var permanent := Mastery.permanent(hero, window.tree_name)
		for tier in range(1, 6):
			var on_left := tier <= LEFT_TIERS
			var col_w := col_l if on_left else col_r
			var col_x := lp.position.x + (tier - 1) * col_l if on_left else rp.position.x + (tier - 1 - LEFT_TIERS) * col_r
			var need := float(data.tier_mastery.get(tier, 0))
			var open := permanent + 0.0001 >= need
			var label := Label.new()
			label.position = Vector2(roundf(col_x), lp.position.y)
			label.size = Vector2(roundf(col_w - GAP.x), TIER_HEADER_H)
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.add_theme_font_size_override("font_size", 16)
			label.add_theme_constant_override("line_spacing", -2)
			label.text = "Tier %d\n%s" % [tier, "open" if open else "needs %d" % int(need)]
			label.add_theme_color_override("font_color", Color(UiPalette.GREEN) if open else Color(UiPalette.RED))
			add_child(label)
			var ids: Array = by_tier.get(tier, [])
			for i in ids.size():
				var ability: AbilityDef = ContentDB.abilities[StringName(ids[i])]
				var n := _Node.new(hero, ability, node_size)
				n.position = Vector2(col_x + (col_w - GAP.x - node_size.x) * 0.5,
						lp.position.y + TIER_HEADER_H + i * row_h).round()
				add_child(n)
				_nodes[ability.id] = n
		for id in _nodes:
			var row: Dictionary = data.ability(id)
			for pre in row.get("prerequisites", {}).get("abilities", []):
				var from: _Node = _nodes.get(StringName(pre))
				if from == null:
					continue
				var to: _Node = _nodes[id]
				var done := hero.is_mastered(StringName(pre))
				# Left to right between tiers; top to bottom within one.
				var sideways := to.position.x > from.position.x + 1.0
				_lines.append([from.position + (Vector2(node_size.x, node_size.y * 0.5) if sideways else Vector2(node_size.x * 0.5, node_size.y)),
						to.position + (Vector2(0, node_size.y * 0.5) if sideways else Vector2(node_size.x * 0.5, 0)),
						Color(UiPalette.GOLD) if done else UiPalette.INK_SOFT])
		queue_redraw()

	func _draw() -> void:
		for l in _lines:
			draw_line(l[0], l[1], l[2], 2.0)

	func node(id: StringName) -> Control:
		return _nodes.get(id)


class _Node:
	extends Button
	var ability: AbilityDef
	var hero: Hero
	var state: State

	func _init(p_hero: Hero, p_ability: AbilityDef, node_size: Vector2) -> void:
		hero = p_hero
		ability = p_ability
		state = AbilityTreeWindow.state_of(hero, ability)
		size = node_size
		custom_minimum_size = node_size
		focus_mode = Control.FOCUS_NONE
		# Long names wrap onto a second line rather than being cut.
		autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		add_theme_font_size_override("font_size", 14)
		text = AbilityTreeWindow.node_text(hero, ability)
		var color: Color = STATE_COLORS[state]
		var style := StyleBoxFlat.new()
		style.bg_color = Color(color.darkened(0.7), 0.95)
		style.border_color = color
		style.set_border_width_all(3 if state in [State.MASTERED, State.LEARNING] else 1)
		style.set_corner_radius_all(4)
		add_theme_stylebox_override("normal", style)
		add_theme_stylebox_override("hover", style)
		add_theme_stylebox_override("pressed", style)
		add_theme_color_override("font_color", color.lightened(0.3) if state != State.NOT_IN_GAME else Color(0.5, 0.5, 0.5))
		var tip := "%s (%s, tier %d)\n%s\nTaught by: %s\n%s" % [ability.display_name, ability.tree, ability.tier,
				ability.description, ability.sheet.get("taught_by", ""), STATE_NAMES[state]]
		if state == State.LOCKED:
			tip += " — " + AbilityTreeWindow.lock_reason(hero, ability)
		var given := TreeRules.contribution(hero, ability)
		tip += "\nMastery from this ability: %d / %d (+%s when learned)" % [floori(given.x), int(given.y),
				str(ability.sheet.get("mastery_on_learn", 0))]
		if hero.find_ability(ability.id) != null:
			tip += "\nDrag onto the action bar."
		tooltip_text = tip

	## What dragging this node carries: only usable abilities go on the bar.
	func drag_payload() -> Variant:
		return {"ability": ability.id} if hero.find_ability(ability.id) != null else null

	func _get_drag_data(_at: Vector2) -> Variant:
		var data: Variant = drag_payload()
		if data != null:
			var preview := Label.new()
			preview.text = ability.display_name
			set_drag_preview(preview)
		return data
