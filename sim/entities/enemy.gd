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
var state: State = State.IDLE
var respawn_at: float = 0.0


func _init(p_id: int = 0, p_def: EnemyDef = null, p_spawn: Vector2i = Vector2i.ZERO) -> void:
	def = p_def if p_def != null else EnemyDef.new()
	super(p_id, Team.ENEMIES, def.stats.copy())
	display_name = def.display_name
	spawn_tile = p_spawn
	move.place(p_spawn)


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
	threat.clear()
	buffs.clear()
	cooldowns = Cooldowns.new()
	move.place(spawn_tile)
