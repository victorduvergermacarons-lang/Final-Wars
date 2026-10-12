class_name QuestDef
extends Resource
## A quest: who offers it, what it needs, and what it pays.

@export var id: StringName = &""
@export var title: String = ""
## What the giver says when offering it.
@export_multiline var offer_text: String = ""
## What the turn-in NPC says while it's not done yet.
@export_multiline var progress_text: String = ""
## What the turn-in NPC says when you hand it in.
@export_multiline var complete_text: String = ""
## NpcDef id of the quest giver.
@export var giver: StringName = &""
## NpcDef id to hand it in to ("" = the giver).
@export var turn_in: StringName = &""
## Quests that must be done first (for chains).
@export var prerequisites: Array[StringName] = []
@export var min_level: int = 1
@export var objectives: Array[QuestObjective] = []
@export var reward_xp: int = 0
@export var reward_gold: int = 0
## Always given.
@export var reward_items: Array[ItemDef] = []
## The player picks one of these (none = no choice).
@export var reward_choices: Array[ItemDef] = []
## World flag the host sets when anyone turns this in ("" = none).
@export var sets_world_flag: StringName = &""
## Announced to everyone in the zone the first time the flag is set.
@export_multiline var world_flag_message: String = ""


func turn_in_npc() -> StringName:
	return turn_in if turn_in != &"" else giver


func validate() -> PackedStringArray:
	var errors: PackedStringArray = []
	if id == &"":
		errors.append("Quest without id")
	if giver == &"":
		errors.append("Quest %s has no giver" % id)
	if objectives.is_empty():
		errors.append("Quest %s has no objectives" % id)
	for o in objectives:
		if o == null:
			errors.append("Quest %s has an empty objective" % id)
		elif o.kind == QuestObjective.Kind.KILL and o.enemy == &"":
			errors.append("Quest %s: kill objective without enemy" % id)
		elif o.kind == QuestObjective.Kind.COLLECT and o.item == null:
			errors.append("Quest %s: collect objective without item" % id)
		elif o.kind == QuestObjective.Kind.TALK and o.npc == &"":
			errors.append("Quest %s: talk objective without npc" % id)
		elif o.kind == QuestObjective.Kind.REACH and o.zone == &"":
			errors.append("Quest %s: reach objective without zone" % id)
	return errors
