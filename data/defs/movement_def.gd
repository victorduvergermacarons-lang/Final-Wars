class_name MovementDef
extends Resource
## How units move (free movement): speeds, acceleration, falls. Tune here
## (content/rules/movement.tres); CombatRules.movement points at it.

## Hero speed in tiles per second (enemies set their own in EnemyDef.move_speed).
@export var walk_speed: float = 3.0
## Multiplies every unit's speed while it is in combat.
@export var combat_speed_factor: float = 1.0
## Seconds from standing still to full speed, and from full speed to a stop.
@export var accel_time: float = 0.10
@export var decel_time: float = 0.08
## Body radius of heroes (tiles); NPCs use npc_radius, enemies EnemyDef.collider_radius.
@export var hero_radius: float = 0.30
@export var npc_radius: float = 0.30

@export_group("Height and falling")
## A drop of at least this many levels is a fall (smaller drops are steps down).
@export var fall_min_levels: int = 2
## Gravity for falls, in height levels per second squared.
@export var gravity: float = 40.0
## Horizontal speed kept while falling (fraction of the speed when leaving the ledge).
@export var fall_carry: float = 0.6
## Falls of more than this many levels hurt.
@export var fall_damage_above: int = 3
## Percent of max HP lost per level fallen beyond fall_damage_above, up to the cap.
@export var fall_damage_percent_per_level: float = 10.0
@export var fall_damage_max_percent: float = 60.0
## Off: a fall leaves at least 1 HP.
@export var fall_damage_can_kill: bool = false
## How fast the drawn height follows a 1-level step (levels per second).
@export var step_smooth_rate: float = 8.0

@export_group("Collision")
## Longest move between collision checks (tiles).
@export var substep: float = 0.2
