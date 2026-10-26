class_name Npc
extends Actor
## A townsperson, quest board, object or caravan: never hostile and stands still.
## While escorted (escort quests) it walks a path on the heroes' side, so enemies
## can attack it and heroes can heal it.

var def: NpcDef
## Where it stands when not escorted (it goes back there after an escort).
var home_tile := Vector2i.ZERO
var home_facing := Vector2i.DOWN
## Being escorted right now (sent to clients: health bar, enemies may attack it).
var escorting := false


func _init(p_id: int = 0, p_def: NpcDef = null, tile: Vector2i = Vector2i.ZERO) -> void:
	def = p_def if p_def != null else NpcDef.new()
	super(p_id, Team.NEUTRAL, StatBlock.make({Stat.Id.HP: maxf(def.max_hp, 1.0),
			Stat.Id.PHYS_DEF: def.phys_def, Stat.Id.MAG_DEF: def.mag_def, Stat.Id.JUMP: 1}))
	display_name = def.display_name
	move.place(tile)
	home_tile = tile


## Starts or ends an escort: on the heroes' side while it lasts.
func set_escorting(on: bool) -> void:
	escorting = on
	team = Team.HEROES if on else Team.NEUTRAL


## Back home, whole and neutral (after an escort ends, or fails).
func reset_home() -> void:
	set_escorting(false)
	alive = true
	hp = stats.hp
	casting = {}
	buffs.clear()
	move.place(home_tile)
	face(home_facing)

