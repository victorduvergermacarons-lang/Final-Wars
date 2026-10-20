class_name CreatureArtDef
extends Resource
## Animated sprite art for a creature: one sheet per animation, frames of
## `frame_size` in a row, one row per facing (see `rows`). Frame counts come from
## the sheet widths. The view builds a SpriteFrames from this ("<anim>_<dir>",
## e.g. "bite_sw"); the numbers here (frame rates, the hit frame) also set the
## timing of the creature's attacks, so damage lands on the right frame.

## Facing directions in screen terms; grid up = NE, right = SE, down = SW, left = NW.
const DIRECTIONS := ["sw", "se", "nw", "ne"]

## Animation name -> sprite sheet (idle, run, bite, howl, death...).
@export var sheets: Dictionary = {}
## The same sheets without shadow (and effects): the hit flash whitens these, so
## the flash covers the body but not its shadow. Optional.
@export var flash_sheets: Dictionary = {}
@export var frame_size: Vector2i = Vector2i(64, 64)
## Which facing each sheet row shows, top row first.
@export var rows: PackedStringArray = PackedStringArray(["sw", "se", "nw", "ne"])
## The point in a frame (pixels from its top-left) that stands on the tile centre.
@export var feet: Vector2 = Vector2(32, 46)
## The top of the creature's head in a frame (where its name and health bar go).
@export var head_y: float = 18.0
## Frames per second per animation. "run" is not listed: it plays
## `run_frames_per_tile` frames per tile walked, at whatever speed the walk takes,
## so the paws keep pace with the ground (match it to how far a planted paw
## travels per frame; the cycle may span several tiles).
@export var fps: Dictionary = {"idle": 6.0, "bite": 30.0, "howl": 10.0, "death": 10.0}
@export var run_frames_per_tile: int = 4
## Animations that loop (others play once and hold their last frame).
@export var looping: PackedStringArray = PackedStringArray(["idle", "run"])
## Ability id -> [animation, hit frame]: the ability winds up for exactly
## hit frame / fps seconds, so its effect lands on that frame. A hit frame of -1
## means the whole animation (e.g. a howl that calls the pack when it ends).
@export var timed_abilities: Dictionary = {}
## Frames still played after an attack's hit frame, during which it stays put.
@export var recovery_frames: Dictionary = {"bite": 2}
## The corpse lies this long after the death animation ends, then fades out.
@export var corpse_seconds: float = 4.0
@export var fade_seconds: float = 1.0
## The sprite flashes white this long when the creature takes damage.
@export var flash_seconds: float = 0.1

@export_group("Recolour")
## Recolours the sheets with view/shaders/creature_recolor.gdshader (e.g. the
## Sunscale Drake's mauve art shown gold and crimson). Flash sheets aren't
## recoloured (they flash white anyway).
@export var recolor: bool = false
@export var recolor_dark: Color = Color(0.22, 0.03, 0.06)
@export var recolor_mid: Color = Color(0.72, 0.13, 0.10)
@export var recolor_light: Color = Color(1.0, 0.80, 0.32)
## 0 = original colours, 1 = fully recoloured.
@export_range(0.0, 1.0) var recolor_strength: float = 1.0
## Pixels at least this saturated keep their colour (flames, eyes).
@export var recolor_keep_saturation: float = 0.45
## Brightness that maps to the mid colour, and how much the gradient is stretched.
@export var recolor_center: float = 0.4
@export var recolor_contrast: float = 1.8


## The shader parameters for the recolour (see creature_recolor.gdshader).
func recolor_params() -> Dictionary:
	return {"dark_color": recolor_dark, "mid_color": recolor_mid, "light_color": recolor_light,
			"strength": recolor_strength, "keep_saturation_above": recolor_keep_saturation,
			"center": recolor_center, "contrast": recolor_contrast}


func frame_count(anim: String) -> int:
	var tex: Texture2D = sheets.get(anim)
	return tex.get_width() / frame_size.x if tex != null else 0


func anim_fps(anim: String) -> float:
	return float(fps.get(anim, 8.0))


## Seconds the whole animation takes (one cycle for loops).
func duration(anim: String) -> float:
	return frame_count(anim) / anim_fps(anim)


## The wind-up an ability needs so its effect lands on its hit frame (-1 if the
## ability isn't timed by this art).
func windup_for(ability_id: StringName) -> float:
	if not timed_abilities.has(ability_id):
		return -1.0
	var entry: Array = timed_abilities[ability_id]
	var anim := str(entry[0])
	var hit := int(entry[1])
	if hit < 0:
		return duration(anim)
	return hit / anim_fps(anim)


## Seconds from death until the corpse has faded away.
func corpse_total() -> float:
	return duration("death") + corpse_seconds + fade_seconds


## Seconds after the hit frame the creature stays busy (recovery frames).
func recovery_for(ability_id: StringName) -> float:
	if not timed_abilities.has(ability_id):
		return 0.0
	var anim := str(timed_abilities[ability_id][0])
	return int(recovery_frames.get(anim, 0)) / anim_fps(anim)


## A SpriteFrames with "<anim>_<dir>" animations cut from the sheets (or from
## another set laid out the same way, like `flash_sheets`).
func build_sprite_frames(from: Dictionary = {}) -> SpriteFrames:
	var source: Dictionary = from if not from.is_empty() else sheets
	var sf := SpriteFrames.new()
	sf.remove_animation(&"default")
	for anim in source:
		var tex: Texture2D = source[anim]
		for r in rows.size():
			var name := StringName("%s_%s" % [anim, rows[r]])
			sf.add_animation(name)
			sf.set_animation_speed(name, anim_fps(anim))
			sf.set_animation_loop(name, looping.has(anim))
			for c in frame_count(anim):
				var at := AtlasTexture.new()
				at.atlas = tex
				at.region = Rect2(Vector2(c * frame_size.x, r * frame_size.y), Vector2(frame_size))
				sf.add_frame(name, at)
	return sf


## The screen facing for a grid facing (4-way).
static func direction_for(facing: Vector2i) -> String:
	match facing:
		Vector2i(0, -1):
			return "ne"
		Vector2i(1, 0):
			return "se"
		Vector2i(-1, 0):
			return "nw"
	return "sw"
