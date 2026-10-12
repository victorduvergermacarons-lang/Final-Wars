class_name QuestDialogue
extends RefCounted
## Quest pages inside the NPC dialogue box: offers ("!"), hand-ins ("?") and
## progress on quests this NPC is waiting for.


## Adds this NPC's quest options to the dialogue's main page.
static func add_options(hud: Hud, npc: Npc) -> void:
	var hero: Hero = hud.session.local_hero()
	if hero == null:
		return
	var quests: Dictionary = ContentDB.quests
	var defs: Array = quests.values()
	defs.sort_custom(func(a, b): return a.title < b.title)
	for def in defs:
		var s := QuestLog.status(hero, def)
		if s == QuestLog.Status.READY and def.turn_in_npc() == npc.def.id:
			hud.dialogue.add_option("? %s (complete)" % def.title, func(): show_turn_in(hud, npc, def))
		elif s == QuestLog.Status.ACTIVE and def.turn_in_npc() == npc.def.id:
			hud.dialogue.add_option("… %s (in progress)" % def.title, func(): show_progress(hud, npc, def))
		elif s == QuestLog.Status.AVAILABLE and def.giver == npc.def.id:
			hud.dialogue.add_option("! %s" % def.title, func(): show_offer(hud, npc, def))


static func show_offer(hud: Hud, npc: Npc, def: QuestDef) -> void:
	var hero: Hero = hud.session.local_hero()
	hud.dialogue.set_text(QuestText.offer_bbcode(hero, def))
	hud.dialogue.clear_options()
	hud.dialogue.add_option("Accept", func():
		hud.session.send_intent({"type": "accept_quest", "npc": npc.id, "quest": def.id}))
	hud.dialogue.add_option("Not now", func(): hud.dialogue.open(npc))


static func show_progress(hud: Hud, npc: Npc, def: QuestDef) -> void:
	var hero: Hero = hud.session.local_hero()
	var said := def.progress_text if def.progress_text != "" else "Come back when it's done."
	hud.dialogue.set_text("[b]%s[/b]\n%s\n\n%s" % [def.title, said, QuestText.objectives_bbcode(hero, def)])
	hud.dialogue.clear_options()
	hud.dialogue.add_option("Back", func(): hud.dialogue.open(npc))


static func show_turn_in(hud: Hud, npc: Npc, def: QuestDef) -> void:
	var said := def.complete_text if def.complete_text != "" else "Well done."
	hud.dialogue.set_text("[b]%s[/b]\n%s\n\n%s" % [def.title, said, QuestText.rewards_bbcode(def)])
	hud.dialogue.clear_options()
	var send := func(choice: int):
		hud.session.send_intent({"type": "turn_in_quest", "npc": npc.id, "quest": def.id, "choice": choice})
	if def.reward_choices.is_empty():
		hud.dialogue.add_option("Complete quest", func(): send.call(-1))
	else:
		for i in def.reward_choices.size():
			var item := def.reward_choices[i]
			var b := ItemButton.new(hud, item, "Complete and take %s" % item.display_name)
			b.pressed.connect(func(): send.call(i))
			hud.dialogue.add_custom_option(b)
	hud.dialogue.add_option("Back", func(): hud.dialogue.open(npc))
