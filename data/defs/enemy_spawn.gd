class_name EnemySpawn
extends Resource
## One enemy placed in a zone. It returns here when leashing and respawns here.

@export var enemy: EnemyDef
@export var tile: Vector2i = Vector2i.ZERO
