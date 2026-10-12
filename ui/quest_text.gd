class_name QuestText
extends RefCounted
## Player-facing quest text (BBCode): objectives with progress, rewards, the
## on-screen tracker and log messages. Pure functions, so they're testable.

const GOLD := "#ffd75e"
const GREEN := "#5fe36b"
const GREY := "#a8a8b0"


## "Wolves slain: 1/2", or "Talk to Old Maren" (done ones turn green with "(done)").
static func objective_line(hero: Hero, def: QuestDef, i: int) -> String:
	var o := def.objectives[i]
	var n := QuestLog.progress(hero, def, i)
	var label := o.text if o.text != "" else _default_text(o)
	var line := label
	if o.kind == QuestObjective.Kind.KILL or o.kind == QuestObjective.Kind.COLLECT:
		line = "%s: %d/%d" % [label, n, o.needed()]
	if n >= o.needed():
		return "[color=%s]• %s (done)[/color]" % [GREEN, line]
	return "• " + line


static func objectives_bbcode(hero: Hero, def: QuestDef) -> String:
	var lines: PackedStringArray = []
	for i in def.objectives.size():
		lines.append(objective_line(hero, def, i))
	return "\n".join(lines)


static func rewards_bbcode(def: QuestDef) -> String:
	var parts: PackedStringArray = []
	if def.reward_xp > 0:
		parts.append("%d XP" % def.reward_xp)
	if def.reward_gold > 0:
		parts.append("[color=%s]%d gold[/color]" % [GOLD, def.reward_gold])
	for item in def.reward_items:
		parts.append(item_name(item))
	var out := "Rewards: " + (", ".join(parts) if not parts.is_empty() else "none")
	if not def.reward_choices.is_empty():
		out += "\nChoose one: " + ", ".join(def.reward_choices.map(func(i): return item_name(i)))
	return out


## Offer page: the giver's text, what to do, and what it pays.
static func offer_bbcode(hero: Hero, def: QuestDef) -> String:
	return "[b]%s[/b]\n%s\n\n%s\n\n%s" % [def.title, def.offer_text, objectives_bbcode(hero, def), rewards_bbcode(def)]


## Tracker for every active quest: title (gold when ready) and objectives.
static func tracker_bbcode(hero: Hero, quests: Dictionary) -> String:
	var blocks: PackedStringArray = []
	for def in active_quests(hero, quests):
		if QuestLog.status(hero, def) == QuestLog.Status.READY:
			var giver := npc_name(def.turn_in_npc())
			blocks.append("[color=%s][b]%s[/b][/color]\n[color=%s]• Return to %s[/color]" % [GOLD, def.title, GREEN, giver])
		else:
			blocks.append("[b]%s[/b]\n%s" % [def.title, objectives_bbcode(hero, def)])
	return "\n".join(blocks)


## The hero's accepted, not yet handed-in quests, sorted by title.
static func active_quests(hero: Hero, quests: Dictionary) -> Array[QuestDef]:
	var out: Array[QuestDef] = []
	for key in hero.quest_state:
		var def: QuestDef = quests.get(StringName(key))
		if def != null and QuestLog.is_active(hero, def.id):
			out.append(def)
	out.sort_custom(func(a, b): return a.title < b.title)
	return out


## A log line for a quest event, or "" if it isn't one.
static func event_message(e: Dictionary, quests: Dictionary) -> String:
	var def: QuestDef = quests.get(StringName(str(e.get("quest", ""))))
	var title: String = def.title if def != null else str(e.get("quest", ""))
	match e.type:
		"quest_accepted":
			return "Quest accepted: %s" % title
		"quest_progress":
			var text: String = e.get("text", "")
			if e.needed > 1:
				return "%s: %d/%d" % [text if text != "" else title, e.count, e.needed]
			return "%s: done" % (text if text != "" else title)
		"quest_ready":
			var who := npc_name(def.turn_in_npc()) if def != null else "the quest giver"
			return "%s complete — return to %s." % [title, who]
		"quest_completed":
			var parts: PackedStringArray = []
			if e.xp > 0:
				parts.append("%d XP" % e.xp)
			if e.gold > 0:
				parts.append("%d gold" % e.gold)
			for id in e.items:
				var item: ItemDef = ContentDB.items.get(StringName(str(id)))
				parts.append(item.display_name if item != null else str(id))
			return "Quest complete: %s%s" % [title, " (" + ", ".join(parts) + ")" if not parts.is_empty() else ""]
		"quest_abandoned":
			return "Quest abandoned: %s" % title
	return ""


static func item_name(item: ItemDef) -> String:
	return "[color=#%s]%s[/color]" % [Rarity.color(item.rarity).to_html(false), item.display_name]


static func npc_name(npc_id: StringName) -> String:
	var npc: NpcDef = ContentDB.npcs.get(npc_id)
	return npc.display_name if npc != null else String(npc_id)


static func _default_text(o: QuestObjective) -> String:
	match o.kind:
		QuestObjective.Kind.KILL:
			var e: EnemyDef = ContentDB.enemies.get(o.enemy)
			return "%s slain" % (e.display_name if e != null else String(o.enemy))
		QuestObjective.Kind.COLLECT:
			return o.item.display_name if o.item != null else "Items"
		QuestObjective.Kind.TALK:
			return "Talk to %s" % npc_name(o.npc)
		QuestObjective.Kind.REACH:
			var z: ZoneDef = ContentDB.zones.get(o.zone)
			return "Explore %s" % (z.display_name if z != null else String(o.zone))
	return ""
