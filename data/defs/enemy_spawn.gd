class_name EnemySpawn
extends Resource
## One enemy placed in a zone. It returns here when leashing and respawns here.

@export var enemy: EnemyDef
@export var tile: Vector2i = Vector2i.ZERO
## Waypoints walked in a loop while idle (empty = stand at the spawn tile).
## A patrolling enemy leashes back to where it was pulled, then resumes.
@export var patrol: Array[Vector2i] = []
## Seconds before it respawns after dying (< 0 = the enemy type's own).
@export var respawn_seconds: float = -1.0
## Its level (0 = the type's own): health, attack, defense and XP change by
## 15% per level, like the debug console's spawns (DebugCommands.at_level).
@export var level: int = 0
