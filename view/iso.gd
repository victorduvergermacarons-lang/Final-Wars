class_name Iso
extends RefCounted
## Isometric projection for the placeholder renderer.
## Grid +x goes screen down-right, grid +y goes screen down-left.

const TILE_W := 64.0
const TILE_H := 32.0
## Pixels a tile rises per height level.
const LEVEL_H := 16.0


## Screen position of the centre of a tile's top face. Accepts fractional tiles
## and heights for interpolated movement.
static func to_screen(tile: Vector2, height: float) -> Vector2:
	return Vector2((tile.x - tile.y) * TILE_W * 0.5, (tile.x + tile.y) * TILE_H * 0.5 - height * LEVEL_H)


## Draw order: larger is nearer the camera.
static func depth(tile: Vector2i) -> int:
	return tile.x + tile.y


## Inverse of to_screen() for a known height: fractional tile position.
static func from_screen(screen: Vector2, height: float) -> Vector2:
	var a := screen.x / (TILE_W * 0.5) # x - y
	var b := (screen.y + height * LEVEL_H) / (TILE_H * 0.5) # x + y
	return Vector2((a + b) * 0.5, (b - a) * 0.5)
