class_name ZoneExit
extends Resource
## Stepping onto `tile` takes a hero to `to_tile` in zone `to_zone`.

@export var tile: Vector2i = Vector2i.ZERO
@export var to_zone: StringName = &""
@export var to_tile: Vector2i = Vector2i.ZERO
