class_name QuestText
extends RefCounted
## Player-facing quest text (BBCode): objectives with progress, rewards, the
## on-screen tracker and log messages. Pure functions, so they're testable.

const GOLD := UiPalette.GOLD
const GREEN := UiPalette.GREEN
const GREY := UiPalette.GREY
const RED := "#a8321e"


## "Wolves slain: 1/2", or "Talk to Old Maren" (done ones turn green with "(done)").
static func objective_line(hero: Hero, def: QuestDef, i: int) -> String:
	var o := def.objectives[i]
	var n := QuestLog.progress(hero, def, i)
	var label := o.text if o.text != "" else _default_text(o)
	var line := label
	if o.kind in [QuestObjective.Kind.KILL, QuestObjective.Kind.COLLECT, QuestObjective.Kind.INVESTIGATE] \
			or (o.kind == QuestObjective.Kind.DELIVER and o.needed() > 1):
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


## Under a quest offer: its title, main or side and where, what to do, what it pays.
static func summary_bbcode(hero: Hero, def: QuestDef) -> String:
	return "[b]%s[/b]  [color=%s]%s[/color]\n%s\n%s" % [def.title, GREY, kind_and_area(def),
			objectives_bbcode(hero, def), rewards_bbcode(def)]


## "Main quest · Greenfields".
static func kind_and_area(def: QuestDef) -> String:
	var kind := "Main quest" if def.is_main() else "Side quest"
	return kind + (" · " + def.area if def.area != "" else "")


## Offer page: the giver's text, what to do, and what it pays.
static func offer_bbcode(hero: Hero, def: QuestDef) -> String:
	return "[b]%s[/b]\n%s\n\n%s\n\n%s" % [def.title, ContentDB.dialogue.text(def.line_id("offer")),
			objectives_bbcode(hero, def), rewards_bbcode(def)]


## Tracker for every active quest (main quests first): title (gold when ready)
## and objectives; failed quests say where to start them again.
static func tracker_bbcode(hero: Hero, quests: Dictionary) -> String:
	var blocks: PackedStringArray = []
	for def in tracked_quests(hero, quests):
		var st := QuestLog.status(hero, def)
		if st == QuestLog.Status.FAILED:
			blocks.append("[b]%s[/b]\n[color=%s]• Failed — talk to %s to try again[/color]" % [def.title, RED, npc_name(def.giver)])
		elif st == QuestLog.Status.READY:
			var giver := npc_name(def.turn_in_npc())
			blocks.append("[color=%s][b]%s[/b][/color]\n[color=%s]• Return to %s[/color]" % [GOLD, def.title, GREEN, giver])
		else:
			blocks.append("[b]%s[/b]\n%s" % [def.title, objectives_bbcode(hero, def)])
	return "\n".join(blocks)


## Active and failed quests for the tracker and the log: main quests first, then
## by title.
static func tracked_quests(hero: Hero, quests: Dictionary) -> Array[QuestDef]:
	var out: Array[QuestDef] = []
	for key in hero.quest_state:
		var def: QuestDef = quests.get(StringName(key))
		if def != null and (QuestLog.is_active(hero, def.id) or QuestLog.is_failed(hero, def.id)):
			out.append(def)
	out.sort_custom(func(a, b):
		if a.category != b.category:
			return a.category < b.category
		return a.title < b.title)
	return out


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
		"quest_failed":
			var giver := npc_name(def.giver) if def != null else "its giver"
			return "Quest failed: %s. Talk to %s to try again." % [title, giver]
		"delivered":
			var item: ItemDef = ContentDB.items.get(StringName(str(e.get("item", ""))))
			return "Delivered %s." % (item.display_name if item != null else "the goods")
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
		QuestObjective.Kind.ESCORT:
			return "Escort %s" % npc_name(o.npc)
		QuestObjective.Kind.DELIVER:
			return "Deliver %s to %s" % [o.item.display_name if o.item != null else "it", npc_name(o.npc)]
		QuestObjective.Kind.INTERACT:
			return "Examine %s" % npc_name(o.npc)
		QuestObjective.Kind.INVESTIGATE:
			return "Places examined"
	return ""
