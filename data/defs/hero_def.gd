class_name HeroDef
extends Resource
## Starting template for a player hero. There are no classes: archetypes come
## from equipped items.

@export var id: StringName = &""
@export var display_name: String = ""
@export var base_stats: StatBlock = StatBlock.new()
## Items the hero owns at start (M1: all four starter items).
@export var starting_items: Array[ItemDef] = []
## Items equipped at start; must also be in starting_items.
@export var starting_equipment: Array[ItemDef] = []
