class_name CharacterSheet
extends PanelContainer
## Character sheet (C): level and XP, every stat split into base / growth / gear /
## buffs, and mastered and in-progress abilities.

var hud: Hud
var _header: Label
var _table: GridContainer
var _abilities: RichTextLabel
var _cells: Array[Label] = []


func _init(p_hud: Hud) -> void:
	hud = p_hud
	custom_minimum_size = Vector2(380, 0)
	var box := VBoxContainer.new()
	add_child(box)
	_header = Label.new()
	box.add_child(_header)
	_table = GridContainer.new()
	_table.columns = 6
	_table.add_theme_constant_override("h_separation", 12)
	box.add_child(_table)
	for h in ["Stat", "Base", "Growth", "Gear", "Buffs", "Total"]:
		var l := _cell(h)
		l.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	for i in Stat.COUNT * 6:
		_cells.append(_cell(""))
	_abilities = RichTextLabel.new()
	_abilities.bbcode_enabled = true
	_abilities.fit_content = true
	_abilities.custom_minimum_size = Vector2(360, 0)
	box.add_child(_abilities)


func _cell(text: String) -> Label:
	var l := Label.new()
	l.text = text
	_table.add_child(l)
	return l


func _process(_delta: float) -> void:
	if not visible:
		return
	var hero: Hero = hud.session.local_hero()
	if hero == null:
		return
	_header.text = "Character (C) — %s, level %d   XP %d / %d" % [hero.display_name, hero.level, hero.xp,
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
	var ab := StatBreakdown.abilities(hero)
	var lines: PackedStringArray = ["[b]Mastered[/b] (usable without their item):"]
	if ab.mastered.is_empty():
		lines.append("  [color=#a8a8b0]none yet[/color]")
	for a in ab.mastered:
		lines.append("  [color=%s]%s[/color]" % [ItemTooltip.GREEN, a.display_name])
	lines.append("[b]In progress:[/b]")
	if ab.in_progress.is_empty():
		lines.append("  [color=#a8a8b0]equip an item that teaches an ability[/color]")
	for p in ab.in_progress:
		lines.append("  %s — AP %d / %d%s" % [p.ability.display_name, p.ap, p.needed,
				"" if p.earning else "  [color=#a8a8b0](item not worn: not earning AP)[/color]"])
	_abilities.text = "\n".join(lines)


static func _num(v: float) -> String:
	return ItemTooltip._num(v)


static func _signed(v: float) -> String:
	if is_zero_approx(v):
		return "—"
	return ("+" if v > 0 else "") + ItemTooltip._num(v)
