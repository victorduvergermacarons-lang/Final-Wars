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
## Ability-tree items by id (built at load time), added to the lists above by ContentDB.
@export var starting_item_ids: Array[StringName] = []
@export var starting_equipment_ids: Array[StringName] = []
## A starting scroll placed in the learning slot (id; ContentDB sets starting_learning).
@export var starting_learning_id: StringName = &""
var starting_learning: ItemDef
