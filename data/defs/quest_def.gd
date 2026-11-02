class_name QuestDef
extends Resource
## A quest: who offers it, what it needs, and what it pays. What the NPCs say about
## it lives in the dialogue file (content/dialogue/act1.json), under
## "quest.<id>.offer", ".progress", ".complete" and friends (see DialogueLines).

enum Category {
	MAIN, ## The story (Act I…).
	SIDE,
}

@export var id: StringName = &""
@export var title: String = ""
@export var category: Category = Category.SIDE
## Where it happens, shown in the quest log (e.g. "Millbrook", "Greenfields").
@export var area: String = ""
## NpcDef id of the quest giver (a person or a quest board).
@export var giver: StringName = &""
## NpcDef id to hand it in to ("" = the giver).
@export var turn_in: StringName = &""
## Quests that must be done first (for chains).
@export var prerequisites: Array[StringName] = []
@export var min_level: int = 1
@export var objectives: Array[QuestObjective] = []
## Handed to you when you accept (e.g. the letter a DELIVER objective asks you to
## bring); taken back if you abandon.
@export var given_items: Array[ItemDef] = []
@export var reward_xp: int = 0
@export var reward_gold: int = 0
## Always given.
@export var reward_items: Array[ItemDef] = []
## The player picks one of these (none = no choice).
@export var reward_choices: Array[ItemDef] = []
## Ability-tree items by id (ContentDB adds them to the two lists above).
@export var reward_item_ids: Array[StringName] = []
@export var reward_choice_ids: Array[StringName] = []
## World flag the host sets when anyone turns this in ("" = none). Its
## announcement is the line "quest.<id>.world_flag".
@export var sets_world_flag: StringName = &""
## Handing it in finishes this act (0 = none): the hero's records note it, and the
## end-of-act screen shows the party's stats, then sends them to `return_zone`.
@export var ends_act: int = 0
@export var return_zone: StringName = &""


func turn_in_npc() -> StringName:
	return turn_in if turn_in != &"" else giver


func is_main() -> bool:
	return category == Category.MAIN


## Line ids for what is said about this quest ("offer", "progress", "complete"…).
func line_id(what: String) -> String:
	return "quest.%s.%s" % [id, what]


## The escort objective's index, or -1.
func escort_objective() -> int:
	for i in objectives.size():
		if objectives[i] != null and objectives[i].kind == QuestObjective.Kind.ESCORT:
			return i
	return -1


func validate() -> PackedStringArray:
	var errors: PackedStringArray = []
	if id == &"":
		errors.append("Quest without id")
	if giver == &"":
		errors.append("Quest %s has no giver" % id)
	if objectives.is_empty():
		errors.append("Quest %s has no objectives" % id)
	var escorts := 0
	for o in objectives:
		if o == null:
			errors.append("Quest %s has an empty objective" % id)
			continue
		var problem := o.validate()
		if problem != "":
			errors.append("Quest %s: %s" % [id, problem])
		if o.kind == QuestObjective.Kind.ESCORT:
			escorts += 1
	if escorts > 1:
		errors.append("Quest %s: at most one escort objective" % id)
	return errors
