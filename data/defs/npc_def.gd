class_name NpcDef
extends Resource
## A friendly townsperson. Vendors and quest givers get their extra roles from
## other definitions (vendor stock, quests) that point back at the NPC's id.

@export var id: StringName = &""
@export var display_name: String = ""
## What the NPC says when you talk to them.
@export_multiline var greeting: String = ""
## Greetings that replace `greeting` once a world flag is set: flag id -> text.
@export var flag_greetings: Dictionary = {}
@export var color: Color = Color(0.95, 0.8, 0.3)
## Goods for sale (unlimited stock). Anyone selling something is a vendor and
## also buys items from players.
@export var sells: Array[ItemDef] = []
## Ability-tree items for sale, by id (ContentDB adds them to `sells`).
@export var sells_ids: Array[StringName] = []


## The greeting for the current world state (`flags`: flag id -> value).
func greeting_for(flags: Dictionary) -> String:
	for flag in flag_greetings:
		if flags.has(String(flag)):
			return flag_greetings[flag]
	return greeting
