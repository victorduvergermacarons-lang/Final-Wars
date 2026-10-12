class_name LootEntry
extends Resource
## One possible drop: `chance` (0..1) to drop between min and max of `item`.

@export var item: ItemDef
## Or an ability-tree item by id (those are built at load time, not .tres files);
## ContentDB fills `item` from it.
@export var item_id: StringName = &""
@export_range(0.0, 1.0) var chance: float = 1.0
@export var min_count: int = 1
@export var max_count: int = 1
## Only drops for heroes who have this quest active ("" = always). Quest items.
@export var quest_id: StringName = &""
