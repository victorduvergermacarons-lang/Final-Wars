class_name Enemy
extends Actor
## A spawned enemy. EnemyBrain drives its state machine.

enum State {
	IDLE, ## Waiting at its spawn point for a hero to come close.
	COMBAT, ## Chasing and attacking the top of its threat table.
	EVADING, ## Leashed: walking home, untargetable.
	DEAD, ## Waiting to respawn.
}

var def: EnemyDef
var spawn_tile := Vector2i.ZERO
## Leash anchor: where it was when it aggroed (its spawn tile unless patrolling).
var home_tile := Vector2i.ZERO
## Patrol waypoints (empty = none) and the index of the next one.
var patrol: Array[Vector2i] = []
var patrol_index: int = 0
var state: State = State.IDLE
var respawn_at: float = 0.0
## When it last used an ability, or aggroed (FLANKER patience).
var last_attack_at: float = 0.0
## Animated creatures stay put until their attack's recovery frames have played.
var busy_until: float = 0.0
## Called into this fight by a pack howl (so it doesn't howl itself).
var called_by_pack := false
## Its level: the type's level, unless spawned at another one (debug console).
var level: int = 1
## Removed when it dies instead of respawning (debug spawns).
var temporary := false


func _init(p_id: int = 0, p_def: EnemyDef = null, p_spawn: Vector2i = Vector2i.ZERO) -> void:
	def = p_def if p_def != null else EnemyDef.new()
	super(p_id, Team.ENEMIES, def.stats.copy())
	display_name = def.display_name
	level = def.level
	weight = def.weight
	spawn_tile = p_spawn
	home_tile = p_spawn
	move.place(p_spawn)


func combat_step_cooldown(rules: CombatRules, now: float) -> float:
	if def.combat_step_seconds > 0.0:
		return def.combat_step_seconds
	return super(rules, now)


## Keeps the threat table so WorldSim can split XP; WorldSim clears it after.
func die() -> void:
	super()
	state = State.DEAD
	evading = false


## Back to full strength at the spawn point.
func reset_at_spawn() -> void:
	alive = true
	hp = stats.hp
	mana = stats.mana
	state = State.IDLE
	evading = false
	called_by_pack = false
	threat.clear()
	buffs.clear()
	last_attack_at = 0.0
	home_tile = spawn_tile
	patrol_index = 0
	cooldowns = Cooldowns.new()
	move.place(spawn_tile)
