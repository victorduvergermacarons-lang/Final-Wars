class_name EnemyDef
extends Resource
## An enemy type. Radii are in tiles (grid distance).

enum Behavior {
	MELEE, ## Chases its target and attacks when in reach (Wolf, Brute).
	KITER, ## Keeps its distance, lines up ranged shots, backs off when approached (Shaman).
	FLANKER, ## Circles to the target's side or back before attacking (Skirmisher).
}

@export var id: StringName = &""
@export var display_name: String = ""
@export var level: int = 1
@export var behavior: Behavior = Behavior.MELEE
## KITER: steps away when a hero is this close or closer.
@export var keep_away_distance: int = 2
@export var stats: StatBlock = StatBlock.new()
@export var abilities: Array[AbilityDef] = []
## Distance at which the enemy notices a hero and aggros.
@export var aggro_radius: int = 4
## Distance from its spawn point at which it gives up and walks home.
@export var leash_radius: int = 10
## Seconds per tile while in combat. 0 = use the Speed stat like heroes do.
@export var combat_step_seconds: float = 0.0
## How far behind reality this enemy perceives heroes' positions (seconds), for
## aggro, chasing and aiming. Lets a hero sidestep an attack. 0 = no delay.
@export var reaction_seconds: float = 0.0
@export var xp_reward: int = 10
## AP given per kill to each participant's equipped-item abilities.
@export var ap_reward: int = 0
## Personal loot each participant rolls.
@export var loot: LootTable
@export var respawn_seconds: float = 30.0
## Elites are shown bigger with a gold outline and "Elite" on their name.
@export var elite: bool = false
## How far knockbacks and pulls move it (Weight.adjust).
@export var weight: Weight.Id = Weight.Id.MEDIUM
## Played once when the enemy first starts fighting (spotting a hero or being
## hit); it stands still while it plays. Enemies a howl calls in don't howl.
@export var howl_ability: AbilityDef
## CALL_PACK: idle enemies of this kind within this many tiles join the fight.
@export var pack_call_radius: int = 0
## Passive: each tile it leaves while fighting gets this ability's AREA effects
## (Salamander Hound's Ember Trail: a short burning ground zone). null = none.
@export var trail_ability: AbilityDef
## Flies (Sunscale Drake): crosses any walkable tile whatever its height, and
## walls, water and other unwalkable tiles up to `fly_over_levels` above it (never
## tall props); ground zones (burning ground) don't touch it while airborne.
@export var flying: bool = false
@export var fly_over_levels: int = 1
## Airborne passive: a knockback from an ability of this tree ("Air") applies
## `grounded_buff` (e.g. stunned and taking more damage), whatever its weight.
@export var grounded_by_tree: String = ""
@export var grounded_buff: BuffDef
## Enrage: below this fraction of its max HP it gains `enrage_buff` (0 = never).
@export var enrage_below: float = 0.0
@export var enrage_buff: BuffDef
## Animated sprite art (null: drawn as a placeholder diamond). Its frame rates
## also time the attacks it lists (see CreatureArtDef.timed_abilities).
@export var art: CreatureArtDef
## Seconds per tile while walking a patrol route (see EnemySpawn.patrol).
@export var patrol_step_seconds: float = 1.0
