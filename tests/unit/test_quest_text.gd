extends GutTest
## Quest text for the dialogue, log, tracker and messages.

var hero: Hero
var quests := {}
var hunt: QuestDef
var token: ItemDef


func before_each() -> void:
	hero = Hero.from_def(1, ContentDB.heroes[&"adventurer"])
	token = ItemDef.new()
	token.id = &"tok"
	token.display_name = "Wolf Token"
	token.max_stack = 20
	hunt = QuestDef.new()
	hunt.id = &"hunt"
	hunt.title = "Wolf Hunt"
	hunt.giver = &"rowan"
	hunt.reward_xp = 60
	hunt.reward_gold = 15
	var k := QuestObjective.new()
	k.kind = QuestObjective.Kind.KILL
	k.enemy = &"wolf"
	k.count = 2
	var c := QuestObjective.new()
	c.kind = QuestObjective.Kind.COLLECT
	c.item = token
	c.count = 3
	c.text = "Tokens"
	var t := QuestObjective.new()
	t.kind = QuestObjective.Kind.TALK
	t.npc = &"maren"
	hunt.objectives = [k, c, t] as Array[QuestObjective]
	var choices: Array[ItemDef] = [ContentDB.items[&"iron_helm"]]
	hunt.reward_choices = choices
	quests = {&"hunt": hunt}


func test_objective_lines_show_progress_and_defaults() -> void:
	QuestLog.accept(hero, hunt)
	assert_eq(QuestText.objective_line(hero, hunt, 0), "• Wolf slain: 0/2", "default text from the enemy name")
	hero.bag.add(token, 3)
	assert_string_contains(QuestText.objective_line(hero, hunt, 1), "Tokens: 3/3 (done)")
	assert_eq(QuestText.objective_line(hero, hunt, 2), "• Talk to Old Maren")


func test_rewards_list_xp_gold_and_choices() -> void:
	var text := QuestText.rewards_bbcode(hunt)
	assert_string_contains(text, "60 XP")
	assert_string_contains(text, "15 gold")
	assert_string_contains(text, "Choose one:")
	assert_string_contains(text, "Iron Helm")


func test_tracker_lists_active_quests_and_ready_ones_say_return() -> void:
	assert_eq(QuestText.tracker_bbcode(hero, quests), "", "nothing tracked without quests")
	QuestLog.accept(hero, hunt)
	assert_string_contains(QuestText.tracker_bbcode(hero, quests), "Wolf Hunt")
	hero.quest_state.hunt.progress = [2, 0, 1]
	hero.bag.add(token, 3)
	assert_string_contains(QuestText.tracker_bbcode(hero, quests), "Return to Captain Rowan")


func test_event_messages() -> void:
	assert_eq(QuestText.event_message({"type": "quest_accepted", "quest": &"hunt"}, quests), "Quest accepted: Wolf Hunt")
	assert_eq(QuestText.event_message({"type": "quest_progress", "quest": &"hunt", "count": 1, "needed": 2,
			"text": "Wolves"}, quests), "Wolves: 1/2")
	assert_eq(QuestText.event_message({"type": "quest_ready", "quest": &"hunt"}, quests),
			"Wolf Hunt complete — return to Captain Rowan.")
	assert_eq(QuestText.event_message({"type": "quest_completed", "quest": &"hunt", "xp": 60, "gold": 15,
			"items": ["iron_helm"]}, quests), "Quest complete: Wolf Hunt (60 XP, 15 gold, Iron Helm)")
	assert_eq(QuestText.event_message({"type": "loot"}, quests), "")


func test_markers() -> void:
	assert_eq(QuestLog.npc_marker(hero, quests, &"rowan"), "!")
	assert_eq(QuestLog.npc_marker(hero, quests, &"maren"), "")
	QuestLog.accept(hero, hunt)
	assert_eq(QuestLog.npc_marker(hero, quests, &"rowan"), "", "in progress: no marker")
	hero.quest_state.hunt.progress = [2, 0, 1]
	hero.bag.add(token, 3)
	assert_eq(QuestLog.npc_marker(hero, quests, &"rowan"), "?")
