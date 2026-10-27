class_name BossEncounterDef
extends Resource
## A dungeon boss fight in phases, as data (BossEncounter runs it). The boss and
## its "heart" are ordinary enemy spawns of the zone, found by their type.
## Phase 1 from full health; phase 2 below phase_at[0] of the boss's health,
## phase 3 below phase_at[1]. From phase 2 the heart pulses every
## pulse_seconds[phase - 1]: it calls `adds` and greys tiles around the heroes
## (ground zones of grey_zone). In phase 3 the boss gains enrage_buff and the heart
## can be hurt; the boss can't fall below boss_floor of its health while the heart
## stands, and breaking the heart ends the fight. A party wipe sends the boss back
## to the start of its current phase.

@export var boss: EnemyDef
@export var heart: EnemyDef
## Boss health fractions where phases 2 and 3 begin.
@export var phase_at: Array[float] = [0.6, 0.25]
## Seconds between heart pulses, per phase (0 = no pulse).
@export var pulse_seconds: Array[float] = [0.0, 11.0, 7.0]
@export var adds: EnemyDef
## Adds called per pulse, per phase; at most max_adds alive at once.
@export var adds_per_pulse: Array[int] = [0, 2, 1]
@export var max_adds: int = 4
## Tiles greyed per pulse, per phase (around the heroes).
@export var grey_tiles_per_pulse: Array[int] = [0, 6, 8]
## The ground-zone ability greyed tiles apply each tick (slows, drains mana).
@export var grey_zone: AbilityDef
@export var grey_seconds: float = 12.0
@export var enrage_buff: BuffDef
@export_range(0.0, 0.5) var boss_floor: float = 0.05
## Who comes in once the heart is broken (an NPC placed at victory_tile).
@export var victory_npc: NpcDef
@export var victory_tile: Vector2i = Vector2i.ZERO


func phase_start(phase: int) -> float:
	return 1.0 if phase <= 1 else phase_at[clampi(phase - 2, 0, phase_at.size() - 1)]


func for_phase(list: Array, phase: int, fallback = 0):
	return list[clampi(phase - 1, 0, list.size() - 1)] if not list.is_empty() else fallback
