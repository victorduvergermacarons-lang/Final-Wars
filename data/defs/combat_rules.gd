class_name CombatRules
extends Resource
## Global tunable constants. One instance lives in content/rules/.
## Later steps add combat math, growth, XP, regen and respawn settings here.

@export_group("Movement")
## Time to walk across one tile (the travel animation), same for everyone.
## Out of combat this is the only limit on stepping: there is no step cooldown,
## the next step can start the moment the previous one arrives.
@export var walk_tile_seconds: float = 0.25
## In-combat step cooldown at 0 Speed.
@export var combat_step_base_seconds: float = 0.6
## Speed can never push the in-combat step cooldown below this.
@export var combat_step_min_seconds: float = 0.3
## Speed at which the step cooldown is halved (before the floor applies).
@export var speed_half_point: float = 100.0

@export_group("Abilities")
@export var gcd_seconds: float = 1.0

@export_group("Line of sight")
## An obstacle blocks only if it rises more than this many levels above the
## sight line (roughly: how tall actors are).
@export var los_height_tolerance: float = 1.0
