class_name ItemTooltip
extends RefCounted
## BBCode text for an item tooltip: name in rarity color, type, stats, growth per
## level, abilities taught with the hero's AP progress, price, and, for items not
## currently worn, a green/red comparison with what they would replace.

const STAT_LABELS := ["HP", "Mana", "Physical Attack", "Magic Attack", "Physical Defense",
	"Magic Defense", "Crit Rate", "Crit Damage", "Speed", "Accuracy", "Evasion", "Jump",
	"Fire Mastery", "Earth Mastery", "Water Mastery", "Air Mastery", "Sword Mastery",
	"Bow Mastery", "Hammer Mastery"]
const GREEN := UiPalette.GREEN
const RED := UiPalette.RED
const GREY := UiPalette.GREY


static func text(item: ItemDef, hero: Hero, rules: CombatRules, worn: bool) -> String:
	var lines: PackedStringArray = []
	lines.append("[color=#%s][b]%s[/b][/color]" % [Rarity.color(item.rarity).to_html(false), item.display_name])
	var kind: String = EquipSlot.TYPE_NAMES[item.slot] if item.is_equippable() else ""
	if item.quest_item:
		lines.append("[color=%s]Quest item[/color]" % UiPalette.GOLD)
	else:
		lines.append("[color=%s]%s%s[/color]" % [GREY, Rarity.NAMES[item.rarity], "  ·  " + kind if kind != "" else ""])
	for id in Stat.all():
		var v := item.stats.get_stat(id)
		if not is_zero_approx(v):
			lines.append("+%s %s" % [_num(v), STAT_LABELS[id]])
	if not item.growth.is_zero():
		var parts: PackedStringArray = []
		for id in Stat.all():
			var g := item.growth.get_stat(id) * rules.growth_fraction
			if not is_zero_approx(g):
				parts.append("+%s %s" % [_num(g), STAT_LABELS[id]])
		lines.append("[color=%s]Per level while %s: %s[/color]" % [GREY,
				"in your learning slot" if item.is_scroll else "worn", ", ".join(parts)])
	for ability in item.teaches:
		var progress := ""
		if hero != null:
			if hero.is_mastered(ability.id):
				progress = " — [color=%s]mastered[/color]" % GREEN
			elif ability.ap_to_master > 0:
				progress = " — AP %d / %d" % [hero.ap.get(ability.id, 0), ability.ap_to_master]
		lines.append("Teaches [b]%s[/b]%s" % [ability.display_name, progress])
		if ability.description != "":
			lines.append("[color=%s]%s[/color]" % [GREY, ability.description])
	if hero != null and item.tree_ability() != null:
		lines.append_array(learning_lines(item, hero))
	if item.description != "":
		lines.append("[i]%s[/i]" % item.description)
	if item.price > 0:
		lines.append("[color=%s]Sells for %d gold[/color]" % [GREY, sell_price(item, rules)])
	if not worn and hero != null and item.is_equippable():
		var cmp := compare(item, hero)
		if not cmp.is_empty():
			lines.append("")
			lines.append("If equipped:")
			lines.append_array(cmp)
	return "\n".join(lines)


const BLUE := UiPalette.BLUE


## Where this ability-tree item stands for the hero: in the learning slot, mastered,
## ready to learn (and how), or locked (and why).
static func learning_lines(item: ItemDef, hero: Hero) -> PackedStringArray:
	var ability := item.tree_ability()
	var out: PackedStringArray = []
	out.append("[color=%s]%s tree, tier %d%s[/color]" % [GREY, ability.tree, ability.tier,
			"  ·  Scroll (not worn)" if item.is_scroll else ""])
	if not ability.implemented:
		out.append("[color=%s]This ability isn't in the game yet.[/color]" % RED)
	elif hero.learning_item == item:
		out.append("[color=%s]In your learning slot: earning AP.[/color]" % BLUE)
	elif hero.active_learning_item() == item:
		out.append("[color=%s]Learning automatically (your learning slot is empty): earning AP.[/color]" % BLUE)
	elif hero.is_mastered(ability.id):
		pass # "mastered" is on the Teaches line
	else:
		var reason := TreeRules.can_learn(hero, ability)
		if reason == "":
			out.append("[color=%s]%s[/color]" % [BLUE, "Right-click or drag onto Learning to learn it." if item.is_scroll
					else "Wield it, then drag it onto Learning to learn it."])
		else:
			out.append("[color=%s]Locked: %s[/color]" % [RED, AbilityTreeWindow.lock_reason(hero, ability)])
	return out


## Lines like "+5 Physical Attack" (green) / "-3 HP" (red): the stat change from
## wearing `item` instead of what it would displace.
static func compare(item: ItemDef, hero: Hero) -> PackedStringArray:
	var delta := item.stats.copy()
	for old in hero.displaced_by(item):
		delta.add(old.stats, -1.0)
	var out: PackedStringArray = []
	for id in Stat.all():
		var v := delta.get_stat(id)
		if not is_zero_approx(v):
			out.append("[color=%s]%s%s %s[/color]" % [GREEN if v > 0 else RED, "+" if v > 0 else "", _num(v), STAT_LABELS[id]])
	return out


static func sell_price(item: ItemDef, rules: CombatRules) -> int:
	return floori(item.price * rules.vendor_sell_fraction)


static func _num(v: float) -> String:
	return str(int(v)) if is_equal_approx(v, roundf(v)) else "%.1f" % v
