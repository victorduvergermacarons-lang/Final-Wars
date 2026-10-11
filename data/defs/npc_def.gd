class_name NpcDef
extends Resource
## A friendly townsperson. Vendors and quest givers get their extra roles from
## other definitions (vendor stock, quests) that point back at the NPC's id.

@export var id: StringName = &""
@export var display_name: String = ""
## What the NPC says when you talk to them.
@export_multiline var greeting: String = ""
@export var color: Color = Color(0.95, 0.8, 0.3)
