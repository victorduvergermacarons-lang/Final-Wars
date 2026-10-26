class_name TileArt
extends RefCounted
## A tileset's images, drawn pixel-exact on the world canvas: one art pixel is
## PixelCamera.ART_SCALE world units, so a 32 px wide tile covers the 64 px wide
## grid cell. Textures load on first use.

static var _cache := {} # tileset id -> TileArt
## Water stays on its first frame (the screenshot test, so pictures can be compared).
static var freeze_water := false

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
	var step := (0 if freeze_water else int(time * float(anim.fps))) + TilesetData.cell_hash(cell, 41) % frames.size()
	return frames[step % frames.size()]


## Water sparkles: about one water tile in SPARKLE_EVERY twinkles, each on its own
## beat (the frames play, then a pause as long as the animation).
const SPARKLE_EVERY := 5


func sparkle_frame(cell: Vector2i, time: float) -> int:
	var anim: Dictionary = data.animations.get("sparkle", {})
	if anim.is_empty() or TilesetData.cell_hash(cell, 31) % SPARKLE_EVERY != 0:
		return -1
	var frames: Array = anim.frames
	var step := (0 if freeze_water else int(time * anim.fps)) + TilesetData.cell_hash(cell, 37) % (frames.size() * 2)
	step %= frames.size() * 2
	return frames[step] if step < frames.size() else -1


## Self-animating versions of the tile animations, for terrain drawn once and
## kept (WorldView's terrain cache): the GPU flips the frames, nothing is
## redrawn. One texture per starting point in the loop, so each cell keeps its
## own phase like animated_frame() and sparkle_frame().
var _animated := {} # "name/phase" -> AnimatedTexture
static var _blank: ImageTexture


## The animation `anim_name` as `cell` shows it (its top block, e.g. the river).
func animated_texture(anim_name: String, cell: Vector2i) -> Texture2D:
	var frames: Array = data.animations.get(anim_name, {}).get("frames", [])
	if frames.is_empty():
		return null
	return _looping(anim_name, frames, 0, TilesetData.cell_hash(cell, 41) % frames.size())


## The sparkle `cell` shows: frames then an equal pause (null: it never sparkles).
func sparkle_texture(cell: Vector2i) -> Texture2D:
	var frames: Array = data.animations.get("sparkle", {}).get("frames", [])
	if frames.is_empty() or TilesetData.cell_hash(cell, 31) % SPARKLE_EVERY != 0:
		return null
	return _looping("sparkle", frames, frames.size(), TilesetData.cell_hash(cell, 37) % (frames.size() * 2))


func _looping(anim_name: String, frames: Array, blanks: int, phase: int) -> AnimatedTexture:
	var key := "%s/%d" % [anim_name, phase]
	if not _animated.has(key):
		if _blank == null:
			var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
			_blank = ImageTexture.create_from_image(img)
		var tex := AnimatedTexture.new()
		tex.frames = frames.size() + blanks
		var fps := float(data.animations[anim_name].fps)
		for i in tex.frames:
			tex.set_frame_texture(i, texture(frames[i]) if i < frames.size() else _blank)
			tex.set_frame_duration(i, 1.0 / fps)
		tex.current_frame = phase
		tex.pause = freeze_water
		_animated[key] = tex
	return _animated[key]


## Props stand on the block below: drawn where a block one level up would be.
func draw_prop(canvas: CanvasItem, tile_id: int, cell: Vector2i, height: int, clip := Rect2()) -> void:
	draw(canvas, tile_id, Iso.to_screen(Vector2(cell), height + 1), Color.WHITE, clip)


## `clip` (when it has an area): draw only the part inside it, in world units on
## whole art pixels, so the part drawn matches the full image pixel for pixel.
func draw(canvas: CanvasItem, tile_id: int, top_center: Vector2, modulate: Color = Color.WHITE, clip := Rect2()) -> void:
	draw_texture(canvas, texture(tile_id), top_center, modulate, clip)


## Like draw(), for a texture in hand (e.g. an animated one).
func draw_texture(canvas: CanvasItem, tex: Texture2D, top_center: Vector2, modulate: Color = Color.WHITE,
		clip := Rect2()) -> void:
	if tex == null:
		return
	var dest := image_rect(top_center)
	if not clip.has_area():
		canvas.draw_texture_rect(tex, dest, false, modulate)
		return
	var part := dest.intersection(clip)
	if not part.has_area():
		return
	var s := PixelCamera.ART_SCALE
	canvas.draw_texture_rect_region(tex, part, Rect2((part.position - dest.position) / s, part.size / s), modulate)


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
