class_name Weight
extends RefCounted
## How heavy a character is: knockbacks and pulls move light characters 1 tile
## further and heavy ones 1 tile less (a 1-tile push doesn't move them).

enum Id { LIGHT, MEDIUM, HEAVY }

const NAMES := ["Light", "Medium", "Heavy"]


## Tiles a knockback or pull of `tiles` really moves a character of `weight`.
static func adjust(tiles: int, weight: Id) -> int:
	match weight:
		Id.LIGHT:
			return tiles + 1
		Id.HEAVY:
			return maxi(tiles - 1, 0)
	return tiles
