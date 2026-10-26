class_name QuestDialogue
extends RefCounted
## Quest pages inside the NPC dialogue box: offers ("!"), offers again after a
## failure, hand-ins ("?") and progress on quests this NPC is waiting for. What
## the NPC says comes from the dialogue file ("quest.<id>.offer" and friends);
## the objectives and rewards are added under it.


## Adds this NPC's quest options to the dialogue's main page (main quests first).
static func add_options(hud: Hud, npc: Npc) -> void:
	var hero: Hero = hud.session.local_hero()
	if hero == null:
		return
	for def in sorted_quests(ContentDB.quests):
		var s := QuestLog.status(hero, def)
		if s == QuestLog.Status.READY and def.turn_in_npc() == npc.def.id:
			hud.dialogue.add_option("? %s (complete)" % def.title, func(): show_turn_in(hud, def))
		elif s == QuestLog.Status.ACTIVE and def.turn_in_npc() == npc.def.id:
			hud.dialogue.add_option("… %s (in progress)" % def.title, func(): show_progress(hud, def))
		elif s == QuestLog.Status.AVAILABLE and def.giver == npc.def.id:
			hud.dialogue.add_option("! %s" % def.title, func(): show_offer(hud, def))
		elif s == QuestLog.Status.FAILED and def.giver == npc.def.id:
			hud.dialogue.add_option("! %s (try again)" % def.title, func(): show_offer(hud, def))


## Main quests first, then side quests; by title within each.
static func sorted_quests(quests: Dictionary) -> Array:
	var defs: Array = quests.values()
	defs.sort_custom(func(a, b):
		if a.category != b.category:
			return a.category < b.category
		return a.title < b.title)
	return defs


static func show_offer(hud: Hud, def: QuestDef) -> void:
	var hero: Hero = hud.session.local_hero()
	var failed := QuestLog.status(hero, def) == QuestLog.Status.FAILED
	var id := def.line_id("restart") if failed and ContentDB.dialogue.has(def.line_id("restart")) else def.line_id("offer")
	hud.dialogue.show_line(id, "…", func():
		hud.dialogue.append_text(QuestText.summary_bbcode(hero, def))
		hud.dialogue.add_option(ContentDB.dialogue.text(def.line_id("accept"), "Accept"), func():
			var npc := hud.dialogue.current_npc()
			if npc != null:
				hud.session.send_intent({"type": "accept_quest", "npc": npc.id, "quest": def.id}))
		hud.dialogue.add_option(ContentDB.dialogue.text(def.line_id("decline"), "Not now"), func():
			if ContentDB.dialogue.has(def.line_id("declined")):
				hud.dialogue.show_line(def.line_id("declined"))
			else:
				hud.dialogue.back_to_main()))


## What the NPC says once you've accepted (if the file has a line for it).
static func show_accepted(hud: Hud, def: QuestDef) -> void:
	if ContentDB.dialogue.has(def.line_id("accepted")):
		hud.dialogue.show_line(def.line_id("accepted"))
	else:
		hud.dialogue.back_to_main()


static func show_progress(hud: Hud, def: QuestDef) -> void:
	var hero: Hero = hud.session.local_hero()
	hud.dialogue.show_line(def.line_id("progress"), "Come back when it's done.", func():
		hud.dialogue.append_text("[b]%s[/b]\n%s" % [def.title, QuestText.objectives_bbcode(hero, def)])
		hud.dialogue.add_option("Back", hud.dialogue.back_to_main))


static func show_turn_in(hud: Hud, def: QuestDef) -> void:
	hud.dialogue.show_line(def.line_id("complete"), "Well done.", func():
		hud.dialogue.append_text("[b]%s[/b]\n%s" % [def.title, QuestText.rewards_bbcode(def)])
		var send := func(choice: int):
			var npc := hud.dialogue.current_npc()
			if npc != null:
				hud.session.send_intent({"type": "turn_in_quest", "npc": npc.id, "quest": def.id, "choice": choice})
		if def.reward_choices.is_empty():
			hud.dialogue.add_option("Complete quest", func(): send.call(-1))
		else:
			for i in def.reward_choices.size():
				var item := def.reward_choices[i]
				var b := ItemButton.new(hud, item, "Complete and take %s" % item.display_name)
				b.pressed.connect(func(): send.call(i))
				hud.dialogue.add_custom_option(b)
		hud.dialogue.add_option("Back", hud.dialogue.back_to_main))
