class_name NpcDef
extends Resource
## A friendly townsperson, a quest board, an object you can examine, or a caravan
## to escort. Vendors and quest givers get their extra roles from other
## definitions (vendor stock, quests) that point back at the NPC's id.
##
## What it says lives in the dialogue file (content/dialogue/act1.json), not here:
## "npc.<id>.greeting", and "npc.<id>.greeting.<world flag>" once that flag is set.

enum Kind {
	PERSON, ## Someone to talk to.
	BOARD, ## A quest board (Guild Board, Mine Board): offers quests like a person.
	OBJECT, ## Something to examine or use (a lever, a shrine, a cart).
	CARAVAN, ## A wagon (escort quests).
}

@export var id: StringName = &""
@export var display_name: String = ""
@export var kind: Kind = Kind.PERSON
## Placeholder colour (shape and portrait frame) and who they side with.
@export var faction: Factions.Id = Factions.Id.TOWNSFOLK
## Art, when it exists. Without it the NPC is drawn as a shape in its faction's
## colour, and its portrait is a frame with its initials.
@export var portrait: Texture2D
@export var art: CreatureArtDef
## Health while being escorted (escort quests only; 0 = it can't be escorted).
@export var max_hp: float = 0.0
@export var phys_def: float = 0.0
@export var mag_def: float = 0.0
## Goods for sale (unlimited stock). Anyone selling something is a vendor and
## also buys items from players.
@export var sells: Array[ItemDef] = []
## Talking to it resets its zone: every enemy back to its spawn at full health,
## lingering effects (ground zones, telegraphs, projectiles, raised terrain, buffs
## and debuffs on everyone there) cleared. The enemy testing map's Reset Shrine.
@export var resets_zone: bool = false
## Ability-tree items for sale, by id (ContentDB adds them to `sells`).
@export var sells_ids: Array[StringName] = []


## The id of the line it greets you with, for the current world state
## (`flags`: flag id -> value): the first set flag that has its own greeting wins.
func greeting_line(flags: Dictionary, lines: DialogueLines) -> String:
	var keys := flags.keys()
	keys.sort()
	for flag in keys:
		var id_for_flag := "npc.%s.greeting.%s" % [id, flag]
		if lines != null and lines.has(id_for_flag):
			return id_for_flag
	return "npc.%s.greeting" % id


func color() -> Color:
	return Factions.color(faction)


## "Captain Rowan" -> "CR", "Hilda" -> "HI".
func initials() -> String:
	return DialogueLines.initials(display_name)
