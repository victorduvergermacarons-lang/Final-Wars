class_name LootTable
extends Resource
## What an enemy can drop. Each participating hero rolls this table separately.

@export var gold_min: int = 0
@export var gold_max: int = 0
@export var entries: Array[LootEntry] = []
