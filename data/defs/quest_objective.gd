class_name QuestObjective
extends Resource
## One thing a quest asks for. Which fields matter depends on `kind`.

enum Kind {
	KILL, ## Kill `count` enemies of type `enemy`.
	COLLECT, ## Have `count` of `item` in the bag (taken at turn-in). Usually quest drops.
	TALK, ## Talk to NPC `npc`.
	REACH, ## Walk within `radius` tiles of `tile` in zone `zone`.
	ESCORT, ## Talk to NPC/caravan `npc` (placed in `zone`) to set off; it walks `path`
	## and must reach the last point alive. If it dies, the quest fails.
	DELIVER, ## Bring `count` of `item` to NPC `npc` (talk to them with it in your bag).
	INTERACT, ## Use the object `npc` (an NpcDef of kind OBJECT) with E.
	INVESTIGATE, ## Examine every spot in `spots` (zone `zone`) with E; the spots glow.
}

@export var kind: Kind = Kind.KILL
## Shown in the quest log and tracker, e.g. "Wolves slain".
@export var text: String = ""
@export var count: int = 1
@export var enemy: StringName = &"" ## KILL: EnemyDef id.
@export var item: ItemDef ## COLLECT, DELIVER.
## TALK, DELIVER: who; INTERACT: the object; ESCORT: who (or what) is escorted.
@export var npc: StringName = &""
@export var zone: StringName = &"" ## REACH, ESCORT, INVESTIGATE.
@export var tile: Vector2i = Vector2i.ZERO ## REACH.
@export var radius: int = 1 ## REACH.
## ESCORT: the waypoints it walks, from where it stands to the last one.
@export var path: Array[Vector2i] = []
## INVESTIGATE: the spots to examine.
@export var spots: Array[Vector2i] = []


## How many are needed (one for TALK, REACH, ESCORT and INTERACT).
func needed() -> int:
	match kind:
		Kind.KILL, Kind.COLLECT, Kind.DELIVER:
			return maxi(count, 1)
		Kind.INVESTIGATE:
			return maxi(spots.size(), 1)
	return 1


## Counted from the bag rather than stored.
func counts_bag() -> bool:
	return kind == Kind.COLLECT


## "" if the objective has what its kind needs, else the problem.
func validate() -> String:
	match kind:
		Kind.KILL:
			if enemy == &"":
				return "kill objective without enemy"
		Kind.COLLECT:
			if item == null:
				return "collect objective without item"
		Kind.TALK:
			if npc == &"":
				return "talk objective without npc"
		Kind.REACH:
			if zone == &"":
				return "reach objective without zone"
		Kind.ESCORT:
			if npc == &"" or zone == &"" or path.is_empty():
				return "escort objective needs npc, zone and path"
		Kind.DELIVER:
			if npc == &"" or item == null:
				return "deliver objective needs npc and item"
		Kind.INTERACT:
			if npc == &"":
				return "interact objective without object"
		Kind.INVESTIGATE:
			if zone == &"" or spots.is_empty():
				return "investigate objective needs zone and spots"
	return ""
