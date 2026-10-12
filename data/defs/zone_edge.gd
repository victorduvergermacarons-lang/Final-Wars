class_name ZoneEdge
extends Resource
## A whole side of a zone that leads into another zone: stepping off the map in
## direction `side` from any tile on that edge arrives on the facing edge of
## `to_zone`. `offset` shifts the position along the edge (e.g. town row 9 +
## offset 13 = Greenfields row 22).

@export var side: Vector2i = Vector2i.RIGHT
@export var to_zone: StringName = &""
@export var offset: int = 0


## Where a hero stepping off `from` (on a grid `src_size` big) lands in a zone of
## size `dst_size`, before checking that the tile is free.
func arrival(from: Vector2i, dst_size: Vector2i) -> Vector2i:
	match side:
		Vector2i.RIGHT:
			return Vector2i(0, from.y + offset)
		Vector2i.LEFT:
			return Vector2i(dst_size.x - 1, from.y + offset)
		Vector2i.DOWN:
			return Vector2i(from.x + offset, 0)
		Vector2i.UP:
			return Vector2i(from.x + offset, dst_size.y - 1)
	return from


## The direction along the edge (for nudging to a free tile nearby).
func along() -> Vector2i:
	return Vector2i(absi(side.y), absi(side.x))
