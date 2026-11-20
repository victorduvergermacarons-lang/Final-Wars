class_name StartingElementDef
extends Resource
## One of the four elements a new character picks (the element screen): what it
## starts with. Its first ability is mastered (its scroll in the bag), its next
## ability's scroll is in the learning slot, and it wears a plain shirt and pants.
## The Rusty Shortsword stays in hand for everyone (HeroDef's starting kit, minus
## the default scrolls). Saved on the hero as `Hero.element`.

@export var id: StringName = &""
@export var display_name: String = ""
## One line for the element screen.
@export var description: String = ""
## Its ability tree's name ("Earth", "Water", "Fire", "Air").
@export var tree: String = ""
## Shown first to last on the element screen.
@export var order: int = 0
@export var color: Color = Color.WHITE
## The ability mastered from the start, and its scroll (kept in the bag).
@export var mastered_ability_id: StringName = &""
@export var mastered_scroll_id: StringName = &""
## The scroll placed in the learning slot.
@export var learning_scroll_id: StringName = &""
## Worn from the start (Chest and Legs).
@export var clothes_ids: Array[StringName] = []
## Its two most important stats (Stat.Id), shown on the element screen; quest
## rewards for this element lean on them.
@export var key_stats: Array[int] = []
