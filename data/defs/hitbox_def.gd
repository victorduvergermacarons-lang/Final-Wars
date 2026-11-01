class_name HitboxDef
extends Resource
## What an ability hits since free movement (docs/FREE_MOVEMENT_PLAN.md §5): a
## shape aimed at the mouse (or a target), tested against units' round bodies.
## Distances in tiles. Built from the spreadsheet's Hitbox columns (TreeContent)
## or written in an enemy ability's .tres. `AbilityDef.hitbox` null = the old tile
## shapes (until every ability is converted).

enum Shape {
	NONE, ## No hitbox: a buff or stance on the caster.
	TARGETED, ## A chosen unit within `reach` (edge to edge) and line of sight.
	CONE, ## From the caster toward the aim: `reach` long, `angle` degrees wide.
	RECT, ## A line from the caster toward the aim: `reach` long, `width` wide.
	CIRCLE, ## A circle of `radius` at the aim point (pulled back to `reach`).
	PROJECTILE, ## Flies toward the aim at `speed`, `size` round, up to `reach`; first unit unless `pierce`.
	LOB, ## Arcs over obstacles onto the aim point (within `reach`), a circle of `radius` where it lands.
	SELF_CIRCLE, ## A circle of `radius` around the caster.
	DASH, ## The caster dashes up to `reach` toward the aim; whoever its `width` sweeps is hit.
	LEAP, ## The caster leaps onto the aim point (within `reach`), a circle of `radius` where it lands.
	BLINK, ## The caster appears at the aim point (within `reach`).
	TILES, ## Terrain and ground zones: the tile under the aim (within `reach`), `radius` tiles around it.
}

@export var shape: Shape = Shape.NONE
## How far it reaches (tiles): the data's "range".
@export var reach: float = 1.0
@export var min_reach: float = 0.0
@export var angle: float = 90.0
@export var width: float = 1.0
@export var radius: float = 1.0
@export var speed: float = 12.0
@export var size: float = 0.25
@export var pierce: bool = false

const NAMES := {"None": Shape.NONE, "Targeted": Shape.TARGETED, "Cone": Shape.CONE, "Line": Shape.RECT,
	"Circle": Shape.CIRCLE, "Projectile": Shape.PROJECTILE, "Lob": Shape.LOB, "Self Circle": Shape.SELF_CIRCLE,
	"Dash": Shape.DASH, "Leap": Shape.LEAP, "Blink": Shape.BLINK, "Tiles": Shape.TILES}


## Built from the data file's hitbox entry ({"shape": name, "range", ...}).
static func from_data(d: Dictionary) -> HitboxDef:
	var h := HitboxDef.new()
	h.shape = NAMES.get(d.get("shape", "None"), Shape.NONE)
	h.reach = float(d.get("range", h.reach))
	h.min_reach = float(d.get("min_range", h.min_reach))
	for key in ["angle", "width", "radius", "speed", "size"]:
		if d.has(key):
			h.set(key, float(d[key]))
	h.pierce = bool(d.get("pierce", false))
	return h


## Shapes aimed at a point or direction (the aim indicator follows the mouse).
func is_aimed() -> bool:
	return shape not in [Shape.NONE, Shape.TARGETED, Shape.SELF_CIRCLE]


## Shapes that stay on the grid (terrain, ground zones).
func on_grid() -> bool:
	return shape == Shape.TILES


func shape_name() -> String:
	return NAMES.find_key(shape) if NAMES.find_key(shape) != null else "None"
