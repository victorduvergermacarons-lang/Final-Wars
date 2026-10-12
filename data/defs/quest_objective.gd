class_name QuestObjective
extends Resource
## One thing a quest asks for. Which fields matter depends on `kind`.

enum Kind {
	KILL, ## Kill `count` enemies of type `enemy`.
	COLLECT, ## Have `count` of `item` in the bag (taken at turn-in). Usually quest drops.
	TALK, ## Talk to NPC `npc`.
	REACH, ## Walk within `radius` tiles of `tile` in zone `zone`.
}

@export var kind: Kind = Kind.KILL
## Shown in the quest log and tracker, e.g. "Wolves slain".
@export var text: String = ""
@export var count: int = 1
@export var enemy: StringName = &"" ## KILL: EnemyDef id.
@export var item: ItemDef ## COLLECT.
@export var npc: StringName = &"" ## TALK: NpcDef id.
@export var zone: StringName = &"" ## REACH: ZoneDef id.
@export var tile: Vector2i = Vector2i.ZERO ## REACH.
@export var radius: int = 1 ## REACH.


## How many are needed (TALK and REACH always need exactly one).
func needed() -> int:
	return maxi(count, 1) if kind == Kind.KILL or kind == Kind.COLLECT else 1
