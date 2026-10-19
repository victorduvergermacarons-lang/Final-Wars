class_name TileArt
extends RefCounted
## A tileset's images, drawn pixel-exact on the world canvas: one art pixel is
## PixelCamera.ART_SCALE world units, so a 32 px wide tile covers the 64 px wide
## grid cell. Textures load on first use.

static var _cache := {} # tileset id -> TileArt

var data: TilesetData
var _textures := {} # tile id -> Texture2D


static func for_tileset(ts: TilesetData) -> TileArt:
	if ts == null:
		return null
	if not _cache.has(ts.id):
		var art := TileArt.new()
		art.data = ts
		_cache[ts.id] = art
	return _cache[ts.id]


func texture(tile_id: int) -> Texture2D:
	if not _textures.has(tile_id):
		var path := data.tile_path(tile_id)
		_textures[tile_id] = load(path) if ResourceLoader.exists(path) else null
	return _textures[tile_id]


## Where a tile's image goes so that a block's top face is centred on
## `top_center` (the grid's Iso.to_screen point for that tile and level).
func image_rect(top_center: Vector2) -> Rect2:
	var s := PixelCamera.ART_SCALE
	var cell := Vector2(data.cell_size)
	# The top face's centre in the image: half the width across, a quarter of the
	# width below the top corner (the diamond is twice as wide as it is tall).
	var face_center := Vector2(cell.x * 0.5, data.top_y + cell.x * 0.25)
	return Rect2(top_center - face_center * s, cell * s)


## The top block of a terrain at `cell` at `time`: a shore terrain picks its
## foam from `land` (sides touching land), an animated one (the river) its frame,
## others a variant by position.
func top_tile(terrain: String, cell: Vector2i, land: Array = [], time: float = 0.0) -> int:
	var tr: Dictionary = data.terrains.get(terrain, {})
	if tr.get("shore", false):
		return data.pick_shore(terrain, land)
	if tr.get("animation", "") != "":
		return animated_frame(tr.animation, cell, time)
	return data.pick(terrain, cell)


## A frame of a looping tile animation. Each cell starts at its own point in
## the loop, so neighbouring tiles don't change in step.
func animated_frame(anim_name: String, cell: Vector2i, time: float) -> int:
	var anim: Dictionary = data.animations.get(anim_name, {})
	var frames: Array = anim.get("frames", [])
	if frames.is_empty():
		return -1
	var step := int(time * float(anim.fps)) + TilesetData.cell_hash(cell, 41) % frames.size()
	return frames[step % frames.size()]


## Water sparkles: about one water tile in SPARKLE_EVERY twinkles, each on its own
## beat (the frames play, then a pause as long as the animation).
const SPARKLE_EVERY := 5


func sparkle_frame(cell: Vector2i, time: float) -> int:
	var anim: Dictionary = data.animations.get("sparkle", {})
	if anim.is_empty() or TilesetData.cell_hash(cell, 31) % SPARKLE_EVERY != 0:
		return -1
	var frames: Array = anim.frames
	var step := int(time * anim.fps) + TilesetData.cell_hash(cell, 37) % (frames.size() * 2)
	step %= frames.size() * 2
	return frames[step] if step < frames.size() else -1


## Props stand on the block below: drawn where a block one level up would be.
func draw_prop(canvas: CanvasItem, tile_id: int, cell: Vector2i, height: int) -> void:
	draw(canvas, tile_id, Iso.to_screen(Vector2(cell), height + 1))


func draw(canvas: CanvasItem, tile_id: int, top_center: Vector2, modulate: Color = Color.WHITE) -> void:
	var tex := texture(tile_id)
	if tex != null:
		canvas.draw_texture_rect(tex, image_rect(top_center), false, modulate)


## The blocks that make up a terrain column of height `height` at `cell`, bottom
## first, as [tile id, level] pairs: the terrain's own block on top, its fill
## terrain below. Levels under `from_level` are left out (hidden behind the tiles
## in front). The top block's variant doesn't depend on the height, so a tile
## raised by an ability keeps its look.
func column(terrain: String, cell: Vector2i, height: int, from_level: int = 0, land: Array = [], time: float = 0.0) -> Array:
	var out := []
	var tr: Dictionary = data.terrains.get(terrain, {})
	if tr.is_empty():
		return out
	var fill: String = tr.fill if tr.fill != "" else terrain
	for level in range(clampi(from_level, 0, height), height + 1):
		if level == height:
			out.append([top_tile(terrain, cell, land, time), level])
		else:
			out.append([data.pick(fill, cell, level + 1), level])
	return out
