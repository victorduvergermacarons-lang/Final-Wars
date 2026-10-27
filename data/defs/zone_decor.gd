class_name ZoneDecor
extends Resource
## A placeholder object on the map (a well, a felt tent, a cairn, an ore cart…)
## where the tileset has no art yet: drawn as a simple shape (DecorPainter) with
## an optional label above it. It stands on one tile and blocks walking there;
## the tall ones (tents, mine entrances) also block line of sight. ZoneDef bakes
## both into walk_rows / sight_rows. Real art can replace a kind later without
## touching the maps.

enum Kind { WELL, DRY_WELL, GER, CAIRN, CART, ANIMAL, SHRINE, STALL, SIGN, MINE, CRATES, LABEL }

## Kinds tall enough to block line of sight.
const BLOCKS_SIGHT := [Kind.GER, Kind.MINE]

@export var kind: Kind = Kind.WELL
@export var tile: Vector2i = Vector2i.ZERO
## Shown above it (small); "" = none. A LABEL decor is only its text (it neither
## draws nor blocks anything), e.g. a building's name on its roof.
@export var label: String = ""
## Main colour; fully transparent = the kind's own.
@export var color: Color = Color(0, 0, 0, 0)


func blocks_walk() -> bool:
	return kind != Kind.LABEL


func blocks_sight() -> bool:
	return BLOCKS_SIGHT.has(kind)
