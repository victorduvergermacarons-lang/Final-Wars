class_name EnemySpawn
extends Resource
## One enemy placed in a zone. It returns here when leashing and respawns here.

@export var enemy: EnemyDef
@export var tile: Vector2i = Vector2i.ZERO
## Waypoints walked in a loop while idle (empty = stand at the spawn tile).
## A patrolling enemy leashes back to where it was pulled, then resumes.
@export var patrol: Array[Vector2i] = []
