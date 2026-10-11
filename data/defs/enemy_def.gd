class_name EnemyDef
extends Resource
## An enemy type. Radii are in tiles (grid distance).

@export var id: StringName = &""
@export var display_name: String = ""
@export var level: int = 1
@export var stats: StatBlock = StatBlock.new()
@export var abilities: Array[AbilityDef] = []
## Distance at which the enemy notices a hero and aggros.
@export var aggro_radius: int = 4
## Distance from its spawn point at which it gives up and walks home.
@export var leash_radius: int = 10
@export var xp_reward: int = 10
@export var respawn_seconds: float = 30.0
