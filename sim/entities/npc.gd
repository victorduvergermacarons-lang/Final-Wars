class_name Npc
extends Actor
## A neutral townsperson: never hostile, can't be attacked or healed, stands still.

var def: NpcDef


func _init(p_id: int = 0, p_def: NpcDef = null, tile: Vector2i = Vector2i.ZERO) -> void:
	def = p_def if p_def != null else NpcDef.new()
	super(p_id, Team.NEUTRAL, StatBlock.make({Stat.Id.HP: 1}))
	display_name = def.display_name
	move.place(tile)
