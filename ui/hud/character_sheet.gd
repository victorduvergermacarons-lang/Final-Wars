class_name CharacterSheet
extends BookSpread
## Character sheet (C), across the menu book: level, XP and every stat split
## into base / growth / gear / buffs on the left page; Mastery, the learning slot
## and mastered and in-progress abilities on the right.

## How far the Abilities page's content sits in from its heading.
const INDENT := 18

var hud: Hud
var _name: Label
var _header: Label
var _table: GridContainer
var _abilities: RichTextLabel
var _mastery: RichTextLabel
var _cells: Array[Label] = []


func _init(p_hud: Hud) -> void:
	super()
	hud = p_hud
	# The name, with level and XP beside it.
	var heading := HBoxContainer.new()
	heading.add_theme_constant_override("separation", 14)
	left.add_child(heading)
	_name = BookSpread.title("")
	heading.add_child(_name)
	_header = Label.new()
	_header.size_flags_vertical = Control.SIZE_SHRINK_END
	_header.add_theme_font_size_override("font_size", 18)
	_header.add_theme_color_override("font_color", UiPalette.INK_SOFT)
	heading.add_child(_header)
	left.add_child(BookSpread.spacer(TOP_GAP)) # the table a little below the name
	_table = GridContainer.new()
	_table.columns = 6
	_table.add_theme_constant_override("h_separation", 10)
	_table.add_theme_constant_override("v_separation", 0)
	left.add_child(_table)
	for h in ["Stat", "Base", "Growth", "Gear", "Buffs", "Total"]:
		var l := _cell(h)
		l.add_theme_color_override("font_color", UiPalette.INK_SOFT)
	for i in Stat.CORE_COUNT * 6:
		_cells.append(_cell(""))
	right.add_child(BookSpread.title("Abilities"))
	# Everything under the heading sits indented from the page's edge.
	var indent := MarginContainer.new()
	indent.add_theme_constant_override("margin_left", INDENT)
	indent.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(indent)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", SEPARATION)
	indent.add_child(body)
	_mastery = RichTextLabel.new()
	_mastery.bbcode_enabled = true
	_mastery.fit_content = true
	body.add_child(_mastery)
	body.add_child(LearningRow.new(hud))
	# Fills the rest of the page and scrolls once the list gets long.
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	_abilities = RichTextLabel.new()
	_abilities.bbcode_enabled = true
	_abilities.fit_content = true
	_abilities.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_abilities)


func _cell(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 18) # six columns have to fit the page
	_table.add_child(l)
	return l


func _process(_delta: float) -> void:
	if not visible:
		return
	var hero: Hero = hud.session.local_hero()
	if hero == null:
		return
	_name.text = hero.display_name
	_header.text = "Level %d  ·  XP %d / %d" % [hero.level, hero.xp,
			Leveling.xp_to_next(hero.level, hud.session.rules())]
	var rows := StatBreakdown.rows(hero, hud.session.now())
	for r in rows:
		var i: int = r.stat * 6
		_cells[i].text = ItemTooltip.STAT_LABELS[r.stat]
		_cells[i + 1].text = _num(r.base)
		_cells[i + 2].text = _signed(r.growth)
		_cells[i + 3].text = _signed(r.gear)
		_cells[i + 4].text = _signed(r.buffs)
		_cells[i + 5].text = _num(r.total)
	var m: PackedStringArray = ["[b]Mastery[/b]"]
	for tree in Mastery.TREES:
		var perm := Mastery.permanent(hero, tree)
		var total := Mastery.total(hero, tree, hud.session.now())
		if is_zero_approx(perm) and is_zero_approx(total):
			continue
		var extra := total - perm
		m.append("  %s %s%s" % [tree, _num(perm), "  [color=%s](+%s from gear)[/color]" % [ItemTooltip.GREEN, _num(extra)] if extra > 0.001 else ""])
	if m.size() == 1:
		m.append("  [color=%s]none yet: master and use abilities to grow it[/color]" % UiPalette.GREY)
	_mastery.text = "\n".join(m)
	var ab := StatBreakdown.abilities(hero)
	var lines: PackedStringArray = ["[b]Mastered[/b] (usable without their item):"]
	if ab.mastered.is_empty():
		lines.append("  [color=%s]none yet[/color]" % UiPalette.GREY)
	for a in ab.mastered:
		lines.append("  [color=%s]%s[/color]" % [ItemTooltip.GREEN, a.display_name])
	lines.append("[b]In progress:[/b]")
	if ab.in_progress.is_empty():
		lines.append("  [color=%s]put a scroll or your weapon in the learning slot[/color]" % UiPalette.GREY)
	for p in ab.in_progress:
		lines.append("  %s — AP %d / %d%s" % [p.ability.display_name, p.ap, p.needed,
				"  [color=%s](learning)[/color]" % UiPalette.BLUE if p.earning and p.ability.is_tree_ability() else (
				"" if p.earning else "  [color=%s](not learning)[/color]" % UiPalette.GREY)])
	_abilities.text = "\n".join(lines)


static func _num(v: float) -> String:
	return ItemTooltip._num(v)


static func _signed(v: float) -> String:
	if is_zero_approx(v):
		return "—"
	return ("+" if v > 0 else "") + ItemTooltip._num(v)
