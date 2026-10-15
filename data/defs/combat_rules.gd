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
@export var combat_exit_seconds: float = 0.0

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
## Per-use tree Mastery only counts against enemies at most this many levels below
## the hero (any level above counts).
@export var mastery_level_window_below: int = 3

@export_group("Targeting")
## Network grace: a skillshot hits a unit that was on the tile at any moment in
## the last this-many seconds (the host resolves all hits).
@export var skillshot_grace_seconds: float = 0.1
## Dodge rule: a skillshot's travel time or a telegraph shorter than the step
## cooldown plus this reaction time can't really be dodged (debug warning).
@export var dodge_reaction_seconds: float = 0.3
## A knockback or pull that slams a unit into a wall, ledge or another unit deals
## this much physical damage (before Mastery and defense) when the ability sets no
## `impact_damage` of its own. The unit it hits takes it too, if hostile to the caster.
@export var collision_damage: float = 8.0

@export_group("Ability power")
## See AbilityPower. Each point of tree Mastery adds this fraction of power.
@export var mastery_power_per_point: float = 0.001
## Each point of tree Mastery lengthens durations by this fraction.
@export var mastery_duration_per_point: float = 0.0005
## Coefficient for each stat named in the sheet's Scales With column.
@export var sheet_stat_coefficient: float = 1.0
## Default base damage / heal of a tree ability effect, by tier 1..5.
@export var tier_damage_base: Array[float] = [10.0, 18.0, 30.0, 45.0, 65.0]
@export var tier_heal_base: Array[float] = [14.0, 24.0, 38.0, 55.0, 80.0]
@export var growth_limit: GrowthLimit = GrowthLimit.NONE
## CAP mode: maximum total growth per stat (0 = that stat is uncapped).
@export var growth_cap: StatBlock = StatBlock.new()
## DIMINISHING mode: growth at which gains are halved, per stat (0 = no falloff).
@export var growth_half_point: StatBlock = StatBlock.new()
## AP given on level-up to every ability taught by an equipped item.
@export var ap_per_level: int = 10
## Refill HP and Mana to full on level-up.
@export var refill_on_level_up: bool = true

@export_group("Economy")
## Vendors pay this fraction of an item's price when you sell it.
@export var vendor_sell_fraction: float = 0.25

@export_group("Flanking")
## Melee (FRONT/ARC) damage bonus when hitting a target from its side / from behind.
@export var flank_side_bonus_percent: float = 25.0
@export var flank_behind_bonus_percent: float = 50.0
## Melee attacks from directly behind can't miss.
@export var behind_never_misses: bool = true

@export_group("XP by level")
## Each level the enemy is above you: +this percent XP, up to the cap.
@export var xp_bonus_percent_per_level_above: float = 10.0
@export var xp_bonus_cap_percent: float = 50.0
## Enemies this many levels below you (or more) start giving less XP…
@export var xp_penalty_from_levels_below: int = 3
## …losing this percent per level from there, down to the floor.
@export var xp_penalty_percent_per_level: float = 20.0
@export var xp_floor_percent: float = 20.0
