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


## `now`: sim time, for the hero's current stats and buffs in the amounts shown.
static func text(item: ItemDef, hero: Hero, rules: CombatRules, worn: bool, now: float = 0.0) -> String:
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
		lines.append("")
		lines.append("Teaches [b]%s[/b]%s" % [ability.display_name, progress])
		lines.append_array(ability_lines(ability, hero, rules, now))
	if item.use_ability != null:
		lines.append("")
		lines.append("[b]Use:[/b]")
		lines.append_array(ability_lines(item.use_ability, hero, rules, now))
		if item.use_ability.cooldown_group != &"":
			lines.append("[color=%s]Shares its cooldown with other %ss.[/color]" % [GREY, item.use_ability.cooldown_group])
	if item.max_stack > 1:
		lines.append("[color=%s]Stacks up to %d.[/color]" % [GREY, item.max_stack])
	if hero != null and item.tree_ability() != null:
		lines.append_array(learning_lines(item, hero))
	if item.description != "" and item.use_ability == null: # a consumable's Use lines say it
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


## The tooltip control showing text(): what item slots, item buttons and item
## labels return from _make_custom_tooltip.
static func label(item: ItemDef, hero: Hero, rules: CombatRules, worn: bool, now: float) -> RichTextLabel:
	var l := RichTextLabel.new()
	l.bbcode_enabled = true
	l.fit_content = true
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	l.custom_minimum_size = Vector2(TOOLTIP_WIDTH, 0)
	for font in ["normal_font_size", "bold_font_size", "italics_font_size", "bold_italics_font_size"]:
		l.add_theme_font_size_override(font, TOOLTIP_FONT_SIZE)
	l.text = text(item, hero, rules, worn, now)
	return l


const TOOLTIP_WIDTH := 340.0
const TOOLTIP_FONT_SIZE := 16
const BLUE := UiPalette.BLUE
const TARGETING := ["", "Targeted", "Skillshot", "Ground", "Self"]


## What an ability does, in numbers for this hero: its description, how it is
## aimed, its costs and timings, each effect (amounts from AbilityPower with the
## hero's current stats and Mastery), what it scales with, and the Mastery it has
## given so far.
static func ability_lines(ability: AbilityDef, hero: Hero, rules: CombatRules, now: float) -> PackedStringArray:
	var out: PackedStringArray = []
	if ability.description != "":
		out.append("[color=%s]%s[/color]" % [GREY, ability.description])
	var how: PackedStringArray = []
	if ability.targeting != AbilityDef.TargetingMode.LEGACY:
		how.append(TARGETING[ability.targeting])
	if ability.max_range > 1 or ability.targeting == AbilityDef.TargetingMode.GROUND:
		how.append("range %s%d" % ["%d–" % ability.min_range if ability.min_range > 1 else "", ability.max_range])
	elif ability.max_range == 1 and ability.target != AbilityDef.TargetType.SELF:
		how.append("adjacent")
	if ability.area_radius > 0:
		how.append("%d×%d area" % [ability.area_radius * 2 + 1, ability.area_radius * 2 + 1])
	if ability.mana_cost > 0.0:
		how.append("%s mana" % _num(ability.mana_cost))
	if ability.cooldown_seconds > 0.0:
		how.append("%ss cooldown" % _num(ability.cooldown_seconds))
	for t in [["cast", ability.cast_seconds], ["wind-up", ability.windup_seconds], ["channel", ability.channel_seconds]]:
		if t[1] > 0.0:
			how.append("%ss %s" % [_num(t[1]), t[0]])
	if not how.is_empty():
		out.append(" · ".join(how))
	for effect in ability.effects:
		if effect != null:
			var line := _effect_line(ability, effect, hero, rules, now)
			if line != "":
				out.append(line)
	var scales: String = ability.sheet.get("scales_with_text", "") if ability.is_tree_ability() else ""
	if scales == "":
		var stats: PackedStringArray = []
		for effect in ability.effects:
			for term in (effect.scaling if effect != null else []):
				if term != null and not stats.has(STAT_LABELS[term.stat]):
					stats.append(STAT_LABELS[term.stat])
		scales = ", ".join(stats)
	if scales != "":
		out.append("[color=%s]Scales with %s.[/color]" % [GREY, scales])
	if hero != null and ability.is_tree_ability():
		var given := TreeRules.contribution(hero, ability)
		if given.y > 0.0:
			out.append("[color=%s]Mastery from using it: %d / %d[/color]" % [GREY, floori(given.x), int(given.y)])
	return out


static func _effect_line(ability: AbilityDef, effect: AbilityEffect, hero: Hero, rules: CombatRules, now: float) -> String:
	var amount := AbilityPower.amount(hero, ability, effect, now, rules) if hero != null else effect.base_amount
	var n := _num(roundf(amount))
	var pct := "%d%% of max %s" % [roundi(effect.percent_of_max * 100.0), "Mana" if effect.kind == AbilityEffect.Kind.RESTORE_MANA else "HP"]
	var how_much := pct if effect.percent_of_max > 0.0 and amount < 0.5 else n
	var secs := _num(effect.buff.duration_seconds) if effect.buff != null else ""
	var kind := "magical" if effect.damage_type == AbilityEffect.DamageType.MAGICAL else "physical"
	match effect.kind:
		AbilityEffect.Kind.DAMAGE:
			return "Deals [b]%s[/b] %s damage" % [n, kind]
		AbilityEffect.Kind.HEAL:
			return "Heals [b]%s[/b]" % how_much
		AbilityEffect.Kind.RESTORE_MANA:
			return "Restores [b]%s[/b]" % (how_much if how_much == pct else how_much + " Mana")
		AbilityEffect.Kind.HEAL_OVER_TIME:
			return "Heals [b]%s[/b] over %ss" % [n, secs]
		AbilityEffect.Kind.DAMAGE_OVER_TIME:
			return "Deals [b]%s[/b] %s damage over %ss" % [n, kind, secs]
		AbilityEffect.Kind.SHIELD:
			return "Shield absorbing [b]%s[/b] for %ss" % [n, secs]
		AbilityEffect.Kind.BUFF:
			return "%s %s for %ss" % ["Inflicts" if effect.buff.is_debuff else "Grants", effect.buff.display_name, secs] \
					if effect.buff != null else ""
		AbilityEffect.Kind.TAUNT:
			return "Taunts: you go to the top of the enemy's threat"
		AbilityEffect.Kind.INTERRUPT:
			return "Interrupts casts and wind-ups"
		AbilityEffect.Kind.RESURRECT:
			return "Brings a fallen ally back to life"
		AbilityEffect.Kind.KNOCKBACK:
			return "Knocks back %s tile%s" % [_num(effect.base_amount), "" if effect.base_amount == 1.0 else "s"]
		AbilityEffect.Kind.PULL:
			return "Pulls up to %s tiles" % _num(effect.base_amount)
		AbilityEffect.Kind.DASH, AbilityEffect.Kind.DASH_TO:
			return "Dashes up to %s tiles" % _num(effect.base_amount)
		AbilityEffect.Kind.LEAP:
			return "Leaps onto the aimed tile"
		AbilityEffect.Kind.BLINK:
			return "Teleports to the aimed tile"
		AbilityEffect.Kind.TERRAIN:
			return "Raises the ground %s level%s for %ss" % [_num(effect.base_amount),
					"" if effect.base_amount == 1.0 else "s", _num(effect.duration_seconds)]
		AbilityEffect.Kind.ZONE:
			var zone := "Leaves a zone on the ground for %ss" % _num(effect.duration_seconds)
			if effect.zone_ability != null:
				for z in effect.zone_ability.effects:
					var inner := _effect_line(effect.zone_ability, z, hero, rules, now) if z != null else ""
					if inner != "":
						return "%s (%s every %ss)" % [zone, inner, _num(effect.zone_tick_seconds)]
			return zone
	return ""


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
