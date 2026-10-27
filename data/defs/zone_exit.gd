class_name ZoneExit
extends Resource
## Stepping onto `tile` takes a hero to `to_tile` in zone `to_zone`. With no
## `to_zone` (or this zone's own id) it is a lift or ladder: a ride to `to_tile` on
## the same map.

@export var tile: Vector2i = Vector2i.ZERO
@export var to_zone: StringName = &""
@export var to_tile: Vector2i = Vector2i.ZERO
