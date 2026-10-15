class_name AbilityTreeWindow
extends PanelContainer
## The ability trees (T): one tab per tree. Each tier is a row with the Mastery it
## needs; abilities show their state (mastered, learning, learnable, locked, not in
## the game yet), AP and how much Mastery they have given toward their cap, with
## lines to their prerequisites. Usable abilities can be dragged onto the action bar.

const NODE_SIZE := Vector2(148, 54)
const GAP := Vector2(12, 26)
const ROW_LABEL_W := 118.0

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
	hud = p_hud
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.08, 0.11, 0.97)
	bg.set_content_margin_all(10)
	bg.set_corner_radius_all(4)
	add_theme_stylebox_override("panel", bg)
	var box := VBoxContainer.new()
	add_child(box)
	var title := Label.new()
	title.text = "Ability trees (T) — drag a usable ability onto the action bar"
	box.add_child(title)
	_tabs = TabBar.new()
	for t in Mastery.TREES:
		_tabs.add_tab(t)
	_tabs.tab_changed.connect(func(i): show_tree(Mastery.TREES[i]))
	box.add_child(_tabs)
	_header = Label.new()
	box.add_child(_header)
	_canvas = _Canvas.new(self)
	box.add_child(_canvas)


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
	var thresholds: PackedStringArray = []
	for tier in range(1, 6):
		thresholds.append(str(int(ContentDB.tree.tier_mastery.get(tier, 0))))
	_header.text = "%s Mastery: %d (unlocks tiers)%s   ·   Tiers need %s" % [tree_name, floori(permanent),
			"  + %d from gear (power only)" % floori(gear) if gear >= 1.0 else "", " / ".join(thresholds)]
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
	if given.y > 0.0:
		progress.append("Mastery %d/%d" % [floori(given.x), int(given.y)])
	lines.append(" · ".join(progress) if not progress.is_empty() else STATE_NAMES[state_of(hero, ability)])
	return "\n".join(lines)


class _Canvas:
	extends Control
	var window: AbilityTreeWindow
	var _nodes := {} # ability id -> _Node
	var _lines: Array = [] # [from Vector2, to Vector2, Color]

	func _init(p_window: AbilityTreeWindow) -> void:
		window = p_window
		custom_minimum_size = Vector2(ROW_LABEL_W + 6 * (NODE_SIZE.x + GAP.x), 5 * (NODE_SIZE.y + GAP.y))

	func rebuild(hero: Hero) -> void:
		for c in get_children():
			c.queue_free()
		_nodes.clear()
		_lines.clear()
		var data: AbilityTreeData = ContentDB.tree
		var by_tier := {}
		for id in data.ids(window.tree_name):
			var row: Dictionary = data.ability(id)
			if not by_tier.has(row.tier):
				by_tier[row.tier] = []
			by_tier[row.tier].append(id)
		var permanent := Mastery.permanent(hero, window.tree_name)
		for tier in range(1, 6):
			var y := (tier - 1) * (NODE_SIZE.y + GAP.y)
			var need := float(data.tier_mastery.get(tier, 0))
			var label := Label.new()
			label.position = Vector2(0, y + 8)
			label.text = "Tier %d\n%s" % [tier, "open" if permanent + 0.0001 >= need else "needs %d" % int(need)]
			label.add_theme_color_override("font_color",
					Color(0.6, 0.9, 0.6) if permanent + 0.0001 >= need else Color(0.75, 0.6, 0.6))
			add_child(label)
			var ids: Array = by_tier.get(tier, [])
			for i in ids.size():
				var ability: AbilityDef = ContentDB.abilities[StringName(ids[i])]
				var n := _Node.new(hero, ability)
				n.position = Vector2(ROW_LABEL_W + i * (NODE_SIZE.x + GAP.x), y)
				add_child(n)
				_nodes[ability.id] = n
		for id in _nodes:
			var row: Dictionary = data.ability(id)
			for pre in row.get("prerequisites", {}).get("abilities", []):
				var from: _Node = _nodes.get(StringName(pre))
				if from == null:
					continue
				var done := hero.is_mastered(StringName(pre))
				_lines.append([from.position + Vector2(NODE_SIZE.x * 0.5, NODE_SIZE.y),
						_nodes[id].position + Vector2(NODE_SIZE.x * 0.5, 0),
						Color(0.85, 0.7, 0.2) if done else Color(0.45, 0.45, 0.5)])
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

	func _init(p_hero: Hero, p_ability: AbilityDef) -> void:
		hero = p_hero
		ability = p_ability
		state = AbilityTreeWindow.state_of(hero, ability)
		size = NODE_SIZE
		custom_minimum_size = NODE_SIZE
		focus_mode = Control.FOCUS_NONE
		clip_text = true
		add_theme_font_size_override("font_size", 12)
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
