class_name CombatRules
extends Resource

enum GrowthLimit {
	NONE, ## Full growth every level.
	CAP, ## Total growth per stat stops at growth_cap.
	DIMINISHING, ## Each level's gain × half_point / (half_point + growth so far).
}
## Global tunable constants. One instance lives in content/rules/.
## Later steps add combat math, growth, XP, regen and respawn settings here.

@export_group("Simulation")
## Fixed sim step (20 Hz).
@export var tick_seconds: float = 0.05

@export_group("Movement")
## Time to walk across one tile (the travel animation), same for everyone.
## Out of combat this is the only limit on stepping: there is no step cooldown,
## the next step can start the moment the previous one arrives.
@export var walk_tile_seconds: float = 0.2
## In-combat step cooldown at 0 Speed.
@export var combat_step_base_seconds: float = 1.5
## Speed can never push the in-combat step cooldown below this.
@export var combat_step_min_seconds: float = 0.5
## Speed at which the step cooldown is halved (before the floor applies).
@export var speed_half_point: float = 100.0

@export_group("Abilities")
@export var gcd_seconds: float = 1.0

@export_group("Line of sight")
## An obstacle blocks only if it rises more than this many levels above the
## sight line (roughly: how tall actors are).
@export var los_height_tolerance: float = 1.0

@export_group("Hit and crit")
## Hit chance in percent = base + (Accuracy − Evasion) × per_point, clamped.
@export var base_hit_percent: float = 95.0
@export var hit_percent_per_point: float = 1.0
@export var min_hit_percent: float = 50.0
@export var max_hit_percent: float = 100.0
## Crit damage bonus every actor has before its Crit Damage stat (percent).
@export var base_crit_damage_percent: float = 50.0

@export_group("Mitigation")
## Damage reduction = Defense / (Defense + K).
@export var physical_defense_k: float = 100.0
@export var magical_defense_k: float = 100.0
## A damage effect that hits always deals at least this much.
@export var min_damage: float = 1.0

@export_group("Height")
## Damage bonus for ranged abilities per height level above the target (percent).
@export var high_ground_bonus_percent_per_level: float = 10.0

@export_group("Threat")
## Healing generates amount × this threat, split across the enemies fighting the
## healed target.
@export var heal_threat_multiplier: float = 0.5
## Taunt sets the caster's threat to the current top threat plus this percent.
@export var taunt_lead_percent: float = 10.0

@export_group("Combat state")
## Seconds after no enemy lists a hero before they leave combat.
@export var combat_exit_seconds: float = 5.0

@export_group("Regen")
## Percent of max per second.
@export var out_of_combat_hp_regen_percent: float = 2.0
@export var out_of_combat_mana_regen_percent: float = 2.0
@export var in_combat_hp_regen_percent: float = 0.0
@export var in_combat_mana_regen_percent: float = 0.5

@export_group("Death")
## HP and Mana fraction a released hero respawns with at the graveyard.
@export var release_fraction: float = 0.5
## HP and Mana fraction restored by a resurrection.
@export var resurrect_fraction: float = 0.3

@export_group("Progression")
## XP needed to go from level L to L+1 = this × L.
@export var xp_per_level_factor: float = 100.0
## Highest reachable level. 0 = no cap.
@export var max_level: int = 0
## Fraction of each equipped item's per-level growth gained on level-up.
@export var growth_fraction: float = 0.5
@export var growth_limit: GrowthLimit = GrowthLimit.NONE
## CAP mode: maximum total growth per stat (0 = that stat is uncapped).
@export var growth_cap: StatBlock = StatBlock.new()
## DIMINISHING mode: growth at which gains are halved, per stat (0 = no falloff).
@export var growth_half_point: StatBlock = StatBlock.new()
## AP given on level-up to every ability taught by an equipped item.
@export var ap_per_level: int = 10
## Refill HP and Mana to full on level-up.
@export var refill_on_level_up: bool = true
