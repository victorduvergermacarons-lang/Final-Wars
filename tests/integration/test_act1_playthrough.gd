extends GutTest
## Act I from start to finish (milestone 3): every quest played in order, through
## the intents a client sends, by one hero and by a party of four (the others
## joining each quest through the co-op prompt). A party finishing every Act I
## quest reaches about level 10 before the Silent Shaft, and a solo hero levels
## the same way (enemies scale with the party, and so does their XP).

const ContentDBScript := preload("res://autoload/content_db.gd")
## Level the party reaches after every quest (target: about 10).
const FINAL_LEVEL := [9, 11]
## How many of Act1Playthrough.ORDER are played (all of them: the level checks
## apply once every quest is in).
const PLAYED := 4


func _quests() -> Array:
	return Act1Playthrough.ORDER.slice(0, PLAYED)

var db


func before_all() -> void:
	db = ContentDBScript.new()


func after_all() -> void:
	db.free()


func _play(size: int) -> Act1Playthrough:
	var run := Act1Playthrough.new(db, size)
	for id in _quests():
		var ok := run.play(id)
		assert_true(ok, "party of %d: %s: %s" % [size, id, run.problem])
		if not ok:
			break
	for entry in run.log:
		gut.p("party of %d: %s  %d kills +%d XP, reward +%d XP -> level %d" % [size, entry[0], entry[4], entry[1], entry[2], entry[3]])
	return run


func test_solo_hero_completes_act1() -> void:
	var run := _play(1)
	var hero := run.leader()
	for id in _quests():
		assert_true(QuestLog.is_done(hero, id), "%s done" % id)
	gut.p("solo: level %d, %d XP in all" % [hero.level, run.total_xp(hero)])
	if PLAYED == Act1Playthrough.ORDER.size():
		assert_between(hero.level, FINAL_LEVEL[0], FINAL_LEVEL[1], "about level 10 before the Silent Shaft")


func test_party_of_four_completes_act1() -> void:
	var run := _play(4)
	for h in run.party:
		for id in _quests():
			assert_true(QuestLog.is_done(h, id), "%s: %s done" % [h.display_name, id])
		if PLAYED == Act1Playthrough.ORDER.size():
			assert_between(h.level, FINAL_LEVEL[0], FINAL_LEVEL[1], "%s: about level 10" % h.display_name)
	assert_eq(run.party.map(func(h): return h.level).max(), run.party.map(func(h): return h.level).min(),
			"the whole party levels together")
	gut.p("party: level %d, %d XP each" % [run.leader().level, run.total_xp(run.leader())])
