class_name QuestListWriter
extends SceneTree
## Writes docs/quests.md, the list of every quest in the game, from the quest files
## in content/quests/ (through ContentDB, so it shows what the game loads):
##   godot --headless --path . -s res://tools/write_quest_list.gd
## Never edit docs/quests.md by hand; a test fails when it is out of date.

const PATH := "res://docs/quests.md"
const ELEMENTS := ["earth", "water", "fire", "air"]
const KIND_NAMES := {
	QuestObjective.Kind.KILL: "Kill",
	QuestObjective.Kind.COLLECT: "Collect",
	QuestObjective.Kind.TALK: "Talk",
	QuestObjective.Kind.REACH: "Reach",
	QuestObjective.Kind.ESCORT: "Escort",
	QuestObjective.Kind.DELIVER: "Deliver",
	QuestObjective.Kind.INTERACT: "Use",
	QuestObjective.Kind.INVESTIGATE: "Investigate",
}


func _init() -> void:
	await process_frame # ContentDB is ready
	var text := build(root.get_node("ContentDB"))
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		printerr("ERROR: can't write %s" % PATH)
		quit(1)
		return
	f.store_string(text)
	f.close()
	print("Wrote %s." % PATH)
	quit()


## Main quests in order, then side quests by level; the order the game's quest log uses.
static func ordered(content) -> Array[QuestDef]:
	var all: Array[QuestDef] = []
	for q: QuestDef in content.quests.values():
		all.append(q)
	all.sort_custom(func(a: QuestDef, b: QuestDef):
		if a.is_main() != b.is_main():
			return a.is_main()
		if a.is_main():
			return String(a.id) < String(b.id)
		if a.min_level != b.min_level:
			return a.min_level < b.min_level
		return a.title < b.title)
	return all


static func build(content) -> String:
	var quests := ordered(content)
	var out := "# Quests\n\n"
	out += "Every quest in the game, written by `tools/write_quest_list.gd` from `content/quests/`\n"
	out += "(regenerate with `godot --headless --path . -s res://tools/write_quest_list.gd`; don't edit\n"
	out += "this file by hand). What people say is in `content/dialogue/act1.json`.\n\n"
	var mains := quests.filter(func(q): return q.is_main()).size()
	out += "%d quests: %d main, %d side.\n\n" % [quests.size(), mains, quests.size() - mains]
	out += "| Quest | Kind | Level | Where | Giver → hand in | XP | Gold |\n"
	out += "|-------|------|-------|-------|-----------------|----|------|\n"
	for q in quests:
		out += "| [%s](#%s) | %s | %d | %s | %s | %d | %d |\n" % [q.title, _anchor(q.title),
				"Main" if q.is_main() else "Side", q.min_level, q.area if q.area != "" else "—",
				_giver_line(content, q), q.reward_xp, q.reward_gold]
	for q in quests:
		out += "\n" + _section(content, q)
	return out


static func _section(content, q: QuestDef) -> String:
	var s := "## %s\n\n" % q.title
	s += "- **Id:** `%s` (`content/quests/%s.tres`)\n" % [q.id, q.id]
	s += "- **%s quest**, level %d%s\n" % ["Main" if q.is_main() else "Side", q.min_level,
			", " + q.area if q.area != "" else ""]
	s += "- **Giver:** %s; **hand in:** %s\n" % [_npc(content, q.giver), _npc(content, q.turn_in_npc())]
	if not q.prerequisites.is_empty():
		s += "- **Needs first:** %s\n" % ", ".join(q.prerequisites.map(func(p): return _quest_title(content, p)))
	if not q.given_items.is_empty():
		s += "- **Handed over on accepting:** %s\n" % _items(q.given_items)
	s += "- **Objectives:**\n"
	for o in q.objectives:
		s += "  - %s\n" % _objective(content, o)
	s += "- **Rewards:** %d XP, %d gold%s\n" % [q.reward_xp, q.reward_gold,
			", " + _items(q.reward_items) if not q.reward_items.is_empty() else ""]
	if not q.reward_choices.is_empty():
		s += "  - Choice of one: %s\n" % _items(q.reward_choices)
	for e in ELEMENTS:
		var given: Array = q.element_rewards.get(e, [])
		var choice: Array = q.element_choices.get(e, [])
		if given.is_empty() and choice.is_empty():
			continue
		var parts: PackedStringArray = []
		if not given.is_empty():
			parts.append("given " + _items(given))
		if not choice.is_empty():
			parts.append("in the choice of one: " + _items(choice))
		s += "  - %s heroes: %s\n" % [e.capitalize(), "; ".join(parts)]
	if q.sets_world_flag != &"":
		s += "- **Sets world flag:** `%s`\n" % q.sets_world_flag
	if q.ends_act > 0:
		s += "- **Ends Act %d**\n" % q.ends_act
	var offer: String = content.dialogue.text(q.line_id("offer")) if content.dialogue != null else ""
	if offer != "":
		s += "\n> %s\n" % offer.replace("\n", " ")
	return s


static func _objective(content, o: QuestObjective) -> String:
	var kind: String = KIND_NAMES.get(o.kind, "?")
	var detail := ""
	match o.kind:
		QuestObjective.Kind.KILL:
			detail = "%d × %s" % [o.needed(), _named(content.enemies, o.enemy)]
		QuestObjective.Kind.COLLECT:
			detail = "%d × %s" % [o.needed(), o.item.display_name if o.item != null else "?"]
		QuestObjective.Kind.TALK, QuestObjective.Kind.INTERACT:
			detail = _npc(content, o.npc)
		QuestObjective.Kind.REACH:
			detail = "within %d tiles of %s in %s" % [o.radius, o.tile, _named(content.zones, o.zone)]
		QuestObjective.Kind.ESCORT:
			detail = "%s in %s, %d waypoints" % [_named(content.npcs, o.npc), _named(content.zones, o.zone), o.path.size()]
		QuestObjective.Kind.DELIVER:
			detail = "%d × %s to %s" % [o.needed(), o.item.display_name if o.item != null else "?", _npc(content, o.npc)]
		QuestObjective.Kind.INVESTIGATE:
			detail = "%d spots in %s" % [o.spots.size(), _named(content.zones, o.zone)]
	return "%s: %s%s" % [kind, detail, " (\"%s\")" % o.text if o.text != "" else ""]


static func _giver_line(content, q: QuestDef) -> String:
	if q.turn_in_npc() == q.giver:
		return _npc(content, q.giver)
	return "%s → %s" % [_npc(content, q.giver), _npc(content, q.turn_in_npc())]


## "Maren Voss (Millbrook)": the NPC's name and the zones it stands in.
static func _npc(content, id: StringName) -> String:
	var npc: NpcDef = content.npcs.get(id)
	var name: String = npc.display_name if npc != null else String(id)
	var places: PackedStringArray = []
	var ids: Array = content.zones.keys()
	ids.sort()
	for zid in ids:
		var z: ZoneDef = content.zones[zid]
		for sp in z.npcs:
			if sp != null and sp.npc != null and sp.npc.id == id and not places.has(z.display_name):
				places.append(z.display_name)
	return name + (" (%s)" % ", ".join(places) if not places.is_empty() else "")


static func _named(dict: Dictionary, id: StringName) -> String:
	var d = dict.get(id)
	return d.display_name if d != null else String(id)


static func _quest_title(content, id: StringName) -> String:
	var q: QuestDef = content.quests.get(id)
	return q.title if q != null else String(id)


static func _items(items: Array) -> String:
	var names: PackedStringArray = []
	var counts := {}
	var order: Array = []
	for it in items:
		if it == null:
			continue
		if not counts.has(it.display_name):
			order.append(it.display_name)
		counts[it.display_name] = counts.get(it.display_name, 0) + 1
	for n in order:
		names.append(n if counts[n] == 1 else "%d × %s" % [counts[n], n])
	return ", ".join(names)


## GitHub's heading anchors: lower case, spaces to dashes, punctuation dropped.
static func _anchor(title: String) -> String:
	var out := ""
	for c in title.to_lower():
		if c == " ":
			out += "-"
		elif (c >= "a" and c <= "z") or (c >= "0" and c <= "9") or c == "-" or c == "_":
			out += c
	return out
