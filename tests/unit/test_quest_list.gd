extends GutTest
## docs/quests.md (written by tools/write_quest_list.gd) lists every quest as the game
## loads it. If this fails, regenerate it:
##   godot --headless --path . -s res://tools/write_quest_list.gd


func test_the_quest_list_is_up_to_date() -> void:
	var on_disk := FileAccess.get_file_as_string(QuestListWriter.PATH)
	assert_ne(on_disk, "", "docs/quests.md exists")
	assert_eq(on_disk, QuestListWriter.build(ContentDB),
			"docs/quests.md is out of date: run tools/write_quest_list.gd")


func test_it_names_every_quest() -> void:
	var text := QuestListWriter.build(ContentDB)
	for q: QuestDef in ContentDB.quests.values():
		assert_string_contains(text, "## %s\n" % q.title)
