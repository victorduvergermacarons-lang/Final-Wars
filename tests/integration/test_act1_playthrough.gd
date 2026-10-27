extends GutTest
## Act I from start to finish (milestones 3 and 4): every quest played in order,
## through the intents a client sends, by one hero (with the dungeon testing
## setting) and by a party of four (the others joining each quest through the
## co-op prompt), from 1-01 to the Silent Shaft, the Foreman, the end-of-act screen
## and the walk home to the Crossing. A party reaches about level 10 before the
## Silent Shaft and about 12 after it; a solo hero levels the same way (enemies
## scale with the party, and so does their XP).

const ContentDBScript := preload("res://autoload/content_db.gd")
## Level the party reaches before the Silent Shaft (about 10) and after it (about 12).
const BEFORE_SHAFT := [9, 11]
const FINAL_LEVEL := [11, 13]
## How many of Act1Playthrough.ORDER are played (all of them: the level checks
## apply once every quest is in).
const PLAYED := 10
const LAST := &"act1_07_the_silent_shaft"


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
	_check_end_of_act(run)
	for entry in run.log:
		gut.p("party of %d: %s  %d kills +%d XP, reward +%d XP -> level %d" % [size, entry[0], entry[4], entry[1], entry[2], entry[3]])
	return run


## The end-of-act screen's data, Act I saved as complete, and back to the Crossing.
func _check_end_of_act(run: Act1Playthrough) -> void:
	if PLAYED < Act1Playthrough.ORDER.size():
		return
	for entry in run.log:
		if entry[0] == &"act1_06_recognition" or entry[0] == &"act1_side_pins_on_the_map":
			assert_between(entry[3], BEFORE_SHAFT[0], BEFORE_SHAFT[1], "about level 10 before the Silent Shaft")
	assert_false(run.act_end.is_empty(), "the end-of-act screen opens")
	assert_eq(run.act_end.get("act", 0), 1)
	assert_eq(run.act_end.get("party", []).size(), run.party.size(), "it shows the whole party")
	for row in run.act_end.get("party", []):
		assert_gt(row.kills, 0, "%s: enemies defeated" % row.name)
		if row.id == run.leader().id: # the short-cut fights: the leader deals every blow
			assert_gt(row.damage, 0, "%s: damage dealt" % row.name)
		assert_eq(row.quests, PLAYED, "%s: every quest handed in" % row.name)
	assert_true(run.world.world_flags.has("act1_complete"), "the world remembers Act I is over")
	for h in run.party:
		var saved := CharacterData.capture(h)
		assert_eq(saved.records.acts, [1], "%s: Act I saved as complete" % h.display_name)
		var back := CharacterData.restore(99, saved, db)
		assert_eq(back.records.acts, [1], "and loads again")
		assert_true(QuestLog.is_done(back, LAST))
	assert_true(run.finish_act(LAST, &"crossing"), "everyone is back at the Crossing")


func test_solo_hero_completes_act1() -> void:
	var run := _play(1)
	var hero := run.leader()
	for id in _quests():
		assert_true(QuestLog.is_done(hero, id), "%s done" % id)
	gut.p("solo: level %d, %d XP in all" % [hero.level, run.total_xp(hero)])
	if PLAYED == Act1Playthrough.ORDER.size():
		assert_between(hero.level, FINAL_LEVEL[0], FINAL_LEVEL[1], "about level 12 at the end of Act I")


func test_party_of_four_completes_act1() -> void:
	var run := _play(4)
	for h in run.party:
		for id in _quests():
			assert_true(QuestLog.is_done(h, id), "%s: %s done" % [h.display_name, id])
		if PLAYED == Act1Playthrough.ORDER.size():
			assert_between(h.level, FINAL_LEVEL[0], FINAL_LEVEL[1], "%s: about level 12" % h.display_name)
	assert_eq(run.party.map(func(h): return h.level).max(), run.party.map(func(h): return h.level).min(),
			"the whole party levels together")
	gut.p("party: level %d, %d XP each" % [run.leader().level, run.total_xp(run.leader())])
