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
## Optional, per facing (a `rows` name): art pixels the body moves on screen per
## run frame, measured from the planted foot. When set, the run cycle follows
## the distance walked on screen (MoveState.screen_odometer) instead of tiles, so
## the feet match the ground whichever way it walks (the hero: walking up the
## screen covers half the pixels of walking across it).
@export var run_px_per_frame: Dictionary = {}
## Facings drawn as another facing's row, flipped left to right: animation ->
## {facing: source facing}. The hero's getting-hit animation: west shows east and
## north-west shows north-east, mirrored (2026-11-19; the drawn W and NW rows looked
## wrong). Same frames, same timing; the flip is about the feet point, so anything
## drawn in the frames (and the body's offset) lands on the mirrored side.
@export var mirror_rows: Dictionary = {}
## Animations that loop (others play once and hold their last frame).
@export var looping: PackedStringArray = PackedStringArray(["idle", "run"])
## Ability id -> [animation, hit frame]: the ability winds up for exactly
## hit frame / fps seconds, so its effect lands on that frame. A hit frame of -1
## means the whole animation (e.g. a howl that calls the pack when it ends).
@export var timed_abilities: Dictionary = {}
## Heroes: ability id -> its own animation, as [animation, weapon tree] (Slash ->
## sword_slash while a Sword is in hand) or, since 2026-11-21, a Dictionary:
##   "anim": played when it goes off, from frame "strike" (the hit lands on the
##     strike frame), or from frame 0 when "from_start" (its release delay waits
##     for the strike: Rock Throw's rock leaves on earth_punch's strike frame);
##   "weapon": the weapon tree it needs in hand ("" = none);
##   "strike": its strike frame (0-based);
##   while its cast or timing bar runs: "windup" once, then "loop" (Rock Throw:
##     earth_root, then earth_hold), or without them the frames before "strike",
##     holding the last (Fire Kick's wind-up).
## Any other ability, or one whose weapon isn't in hand, plays "cast".
@export var ability_anims: Dictionary = {}
## Frames still played after an attack's hit frame, during which it stays put.
@export var recovery_frames: Dictionary = {"bite": 2}
## The corpse lies this long after the death animation ends, then fades out.
@export var corpse_seconds: float = 4.0
@export var fade_seconds: float = 1.0
## The sprite flashes white this long when the creature takes damage.
@export var flash_seconds: float = 0.1

@export_group("Missing animations (fallbacks)")
## Used only while the sheet they stand in for is missing, so real sheets drop in
## later by adding them (plus `timed_abilities` for an attack) with no code change.
## No attack sheet for an ability it uses (not in `timed_abilities`): during the
## wind-up it holds the last frame of `fallback_attack_anim`, then lunges this many
## art pixels toward its facing on the hit and back over `fallback_lunge_seconds`.
@export var fallback_attack_anim: String = "run"
@export var fallback_lunge_px: float = 6.0
@export var fallback_lunge_seconds: float = 0.2
## No "death" sheet: it holds idle's first frame and tips over onto its side over
## this many seconds, lies `corpse_seconds`, then fades over `fade_seconds`.
@export var fallback_death_tip_seconds: float = 0.35

## Looks a buff can give (BuffDef.look) -> creature_recolor.gdshader parameters
## ("dark_color", "mid_color", "light_color", "strength", "keep_saturation_above",
## "center", "contrast"): the sheets are baked once through the shader with them
## and drawn instead while the buff lasts (Stone Skin's grey stone).
@export var looks: Dictionary = {}
## Heroes: what plays on entering a bending stance (stance rework), by "<Tree>:<n>":
## an animation name, or [first, then] (then holds `stance_hold_seconds`). Missing:
## `stance_anim_default` ("cast"). The approved stance-entry animations drop in here.
@export var stance_anims: Dictionary = {}
@export var stance_anim_default: String = "cast"
@export var stance_hold_seconds: float = 0.6

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


## `ability_id`'s entry in ability_anims as a Dictionary ({} if none): "anim",
## "weapon", "strike", "windup", "loop", "from_start".
func ability_anim(ability_id: StringName) -> Dictionary:
	var e = ability_anims.get(ability_id)
	if e is Array and e.size() == 2:
		return {"anim": str(e[0]), "weapon": str(e[1]), "strike": 0, "windup": "", "loop": "", "from_start": false}
	if e is Dictionary:
		return {"anim": str(e.get("anim", "")), "weapon": str(e.get("weapon", "")), "strike": int(e.get("strike", 0)),
				"windup": str(e.get("windup", "")), "loop": str(e.get("loop", "")),
				"from_start": bool(e.get("from_start", false))}
	return {}


## Seconds from the start of `ability_id`'s animation to its strike frame (0: none).
func strike_seconds(ability_id: StringName) -> float:
	var e := ability_anim(ability_id)
	if e.is_empty() or e.strike <= 0 or not sheets.has(e.anim):
		return 0.0
	return e.strike / anim_fps(e.anim)


## Seconds the whole animation takes (one cycle for loops).
## The stance-entry animation for `tree`'s stance `n`: [anim] or [first, then],
## only names this art has.
func stance_anim(tree: String, n: int) -> Array:
	var e = stance_anims.get("%s:%d" % [tree, n], stance_anim_default)
	var names: Array = e if e is Array else [e]
	return names.filter(func(a): return sheets.has(str(a)))


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


## Seconds the death takes before the corpse lies still (the death animation, or
## the tip-over fallback).
func death_length() -> float:
	return duration("death") if sheets.has("death") else fallback_death_tip_seconds


## Seconds from death until the corpse has faded away.
func corpse_total() -> float:
	return death_length() + corpse_seconds + fade_seconds


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


## Applies `mirror_rows` to a pick ({"anim", "dir", ...}): the source row and
## "flip": true when that facing is drawn mirrored.
func mirrored(pick: Dictionary) -> Dictionary:
	var m: Dictionary = mirror_rows.get(pick.get("anim", ""), {})
	if m.has(pick.get("dir", "")):
		pick.dir = m[pick.dir]
		pick.flip = true
	return pick


## The run frame after walking `move` (MoveState) facing `dir`. A walk listed in
## `fps` ("run" / "walk", the Critters pack) plays by time at that rate instead.
func run_frame(move: MoveState, dir: String, anim: String = "run", t: float = 0.0) -> int:
	var n := maxi(frame_count(anim), 1)
	if fps.has(anim):
		return int(t * anim_fps(anim)) % n
	var px := float(run_px_per_frame.get(dir, 0.0))
	if px > 0.0:
		return int(move.screen_odometer / px) % n
	return int(move.odometer * run_frames_per_tile) % n


## Art with 8 rows (the hero): the screen facing for a grid-space angle, in eight
## equal slices of 45° (grid axes are the diagonal views, grid diagonals the
## straight ones: screen up is grid (-1, -1)). Otherwise the 4-way facing.
func direction_for_angle(angle: float, facing: Vector2i) -> String:
	if rows.size() < 8:
		return direction_for(facing)
	var k := posmod(roundi(angle / (PI / 4.0)), 8)
	return ["se", "s", "sw", "w", "nw", "n", "ne", "e"][k]


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
