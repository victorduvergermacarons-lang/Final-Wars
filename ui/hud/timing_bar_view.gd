class_name TimingBarView
extends Control
## The local hero's timing bar (TimingBarDef) under the ability's name: green zones
## (tap), yellow zones (tap: sure crit) and blue zones (hold right-click from start
## to end). After the press it shows the result ("Perfect!", "Good", "Miss"; a hold
## also its accuracy) for a moment. Time always moves at the same speed on screen
## (FULL_SECONDS fill the bar's full length), in one of two modes:
## - LENGTH: the bar is as long as the ability (a 1 s bar is a third of the full
##   length, centred) and a cursor sweeps across it
## - SCROLL: the bar keeps its full length; the zones slide toward a fixed hit line
## Options (the Escape menu's Gameplay test tab; saved on this computer): where
## (under the hero, or above the action bar) and the mode.

enum Place { BELOW_HERO, ACTION_BAR } # saved as ints (an old 2, "over the hero", reads as under)
enum Mode { LENGTH, SCROLL } # saved as ints

## The full bar above the action bar; under the hero it is half as long and tall.
const BAR := Vector2(440, 30)
## Seconds of bar the full length stands for (both modes: the speed on screen).
const FULL_SECONDS := 3.0
## SCROLL: the hit line sits this many seconds of track from the left edge, so a
## zone just passed stays in sight a moment.
const HIT_LEAD_SECONDS := 0.4
## Space above the bar for the ability's name and the result.
const LABEL_HEIGHT := 26.0
## Gap between the hero's feet (or the action bar) and the bar.
const GAP := 34.0
const RESULT_SECONDS := 0.8
const BACK := Color(0.06, 0.06, 0.08, 0.88)
const EDGE := Color(0.92, 0.92, 0.92)
const GREEN := Color(0.2, 0.85, 0.3)
const YELLOW := Color(1.0, 0.85, 0.15)
const BLUE := Color(0.2, 0.5, 1.0)
const BLUE_HELD := Color(0.65, 0.88, 1.0)
## A hold pressed before its zone or held past it.
const MISTIMED := Color(1.0, 0.35, 0.3)
const END_MARK := Color(1, 1, 1, 0.45)
const GRADE_TEXT := {"perfect": "Perfect!", "good": "Good", "miss": "Miss"}
const GRADE_COLOR := {"perfect": Color(1.0, 0.88, 0.3), "good": Color(0.35, 0.95, 0.45), "miss": Color(0.8, 0.8, 0.8)}

var hud: Hud
var place: int = Place.BELOW_HERO # Place
var mode: int = Mode.LENGTH # Mode
## The bar being shown: {"bar": TimingBarDef, "start": float, "name": String}.
var _shown := {}
## After the press: {"grade", "at", "until" (real seconds)}.
var _result := {}


func _init(p_hud: Hud) -> void:
	hud = p_hud
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


## The host judged the local hero's bar (`at` < 0: no press in time; `accuracy`:
## a hold's, shown as a percentage, or -1).
func show_result(grade: String, at: float, accuracy: float = -1.0) -> void:
	_result = {"grade": grade, "at": at, "accuracy": accuracy, "until": _real_now() + RESULT_SECONDS}


func _process(_delta: float) -> void:
	var hero: Hero = hud.session.local_hero() if hud.session != null else null
	var c: Dictionary = hero.casting if hero != null else {}
	var active: bool = not c.is_empty() and c.get("kind", "") == "timing" \
			and c.ability is AbilityDef and c.ability.timing_bar != null
	if active and float(c.start) != float(_shown.get("start", -1.0)):
		_shown = {"bar": c.ability.timing_bar, "start": float(c.start), "name": c.ability.display_name}
		_result = {}
	var showing_result: bool = not _result.is_empty() and _real_now() < float(_result.until)
	visible = (active or showing_result) and not _shown.is_empty() and hero != null
	if not visible:
		return
	size = Vector2(_bar_size().x, _bar_size().y + LABEL_HEIGHT)
	position = _place_for(hero).round()
	# The result fades out over the second half of its time.
	modulate.a = clampf((_result.until - _real_now()) / RESULT_SECONDS * 2.0, 0.0, 1.0) if showing_result and not active else 1.0
	queue_redraw()


func _place_for(hero: Hero) -> Vector2:
	var screen := get_viewport_rect().size
	var at: Vector2
	if place == Place.ACTION_BAR:
		var bar_rect := hud.action_bar_rect()
		at = Vector2(bar_rect.get_center().x - size.x / 2.0, bar_rect.position.y - GAP - size.y)
	else:
		var view = hud.input.view if hud.input != null else null # WorldView
		if view == null:
			return Vector2((screen.x - size.x) / 2.0, screen.y * 0.6)
		var feet: Vector2 = view.get_canvas_transform() * view.actor_screen_pos(hero)
		at = feet + Vector2(-size.x / 2.0, GAP - LABEL_HEIGHT)
	return at.clamp(Vector2.ZERO, (screen - size).max(Vector2.ZERO))


## The full bar: above the action bar, or half that by the hero.
func _full() -> Vector2:
	return BAR if place == Place.ACTION_BAR else BAR / 2.0


## Pixels per second of bar (the same for every ability).
func _speed() -> float:
	return _full().x / FULL_SECONDS


func _bar_size() -> Vector2:
	var s := _full()
	var bar: TimingBarDef = _shown.get("bar")
	if mode == Mode.LENGTH and bar != null:
		s.x = minf(_speed() * bar.seconds, get_viewport_rect().size.x - 20.0)
	return s


## Seconds into the bar to show: running, stopped at a tap or at a hold's release,
## or where the result was judged.
func _shown_time(seconds: float) -> float:
	var t: float = hud.session.render_time() - float(_shown.start)
	# Every input played (the last one a tap, or a hold let go): stop where it ended.
	var presses := _presses()
	var bar: TimingBarDef = _shown.bar
	if not presses.is_empty() and int(hud.client.timing_press.get("next", 0)) >= bar.inputs().size():
		var last: Dictionary = presses.back()
		if not last.holding:
			t = float(last.at)
		elif last.has("release"):
			t = float(last.release)
	if not _result.is_empty():
		t = float(_result.at) if float(_result.at) >= 0.0 else seconds
	return clampf(t, 0.0, seconds)


## The local presses on the bar being shown (PlayerInput keeps them in ClientState).
func _presses() -> Array:
	var state: Dictionary = hud.client.timing_press
	return state.get("presses", []) if float(state.get("start", -1.0)) == float(_shown.start) else []


## Where `time` (seconds into the bar) is drawn when the bar shows time `t`.
func _x(time: float, t: float) -> float:
	if mode == Mode.SCROLL:
		return (HIT_LEAD_SECONDS + time - t) * _speed()
	return time * _speed()


## The part of the bar from `from` to `to` seconds, cut to the bar (empty if outside).
func _span(from: float, to: float, t: float, top: float, s: Vector2) -> Rect2:
	var a := clampf(_x(from, t), 0.0, s.x)
	var b := clampf(_x(to, t), 0.0, s.x)
	return Rect2(a, top, maxf(b - a, 0.0), s.y)


func _draw() -> void:
	var bar: TimingBarDef = _shown.get("bar")
	if bar == null:
		return
	var seconds := maxf(bar.seconds, 0.01)
	var t := _shown_time(seconds)
	var s := _bar_size()
	var top := LABEL_HEIGHT
	var rect := Rect2(0, top, s.x, s.y)
	draw_rect(rect.grow(2), Color.BLACK)
	draw_rect(rect, BACK)
	for z in bar.zones:
		_fill(_span(z.x, z.x + z.y, t, top, s), GREEN)
	for z in bar.crit_zones:
		_fill(_span(z.x, z.x + z.y, t, top, s), YELLOW)
	for z in bar.hold_zones:
		_fill(_span(z.x, z.x + z.y, t, top, s), BLUE)
	# What has been played so far: each hold light blue inside its zone and red where
	# it was mistimed (pressed before the zone, or still held after it); each tap a
	# small white mark (more inputs may follow, so the cursor keeps going).
	var inputs := bar.inputs()
	var holding := false # a hold in progress
	var over := false # …held past its zone's end
	for p in _presses():
		var input: Dictionary = inputs[int(p.index)]
		var from := float(p.at)
		if p.holding:
			var zone: Vector2 = input.zone
			var held_to: float = float(p.get("release", t))
			var zone_end: float = zone.x + zone.y
			_fill(_span(from, minf(held_to, zone.x), t, top, s), MISTIMED)
			_fill(_span(maxf(from, zone.x), minf(held_to, zone_end), t, top, s), BLUE_HELD)
			_fill(_span(zone_end, held_to, t, top, s), MISTIMED)
			if not p.has("release"):
				holding = true
				over = held_to > zone_end
		else:
			var px := _x(from, t)
			if px >= 0.0 and px <= s.x:
				draw_rect(Rect2(px - 1, top + 2, 2, s.y - 4), Color(1, 1, 1, 0.8))
	if mode == Mode.SCROLL:
		# Where the ability's bar starts and ends, sliding along with the zones.
		for edge in [0.0, seconds]:
			var ex := _x(edge, t)
			if ex > 0.0 and ex < s.x:
				draw_rect(Rect2(ex - 1, top, 2, s.y), END_MARK)
	draw_rect(rect, EDGE, false, 2.0)

	# The cursor (LENGTH) or the fixed hit line (SCROLL): a tall white line.
	var x := _x(t, t)
	draw_rect(Rect2(x - 3, top - 7, 6, s.y + 14), Color.BLACK)
	draw_rect(Rect2(x - 1.5, top - 6, 3, s.y + 12), Color.WHITE)

	var font := get_theme_default_font()
	var text: String = _shown.name
	var color := Color.WHITE
	var font_size := 18
	if not _result.is_empty():
		text = GRADE_TEXT.get(_result.grade, "")
		if float(_result.get("accuracy", -1.0)) >= 0.0 and _result.grade != "perfect":
			text += " %d%%" % roundi(float(_result.accuracy) * 100.0) # a hold's accuracy
		color = GRADE_COLOR.get(_result.grade, Color.WHITE)
		font_size = 22
	elif holding:
		text = "Let go!" if over else "Hold!"
		color = MISTIMED if over else BLUE_HELD
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var pos := Vector2((s.x - width) / 2.0, top - 6)
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 5, Color.BLACK)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _fill(r: Rect2, color: Color) -> void:
	if r.size.x > 0.0:
		draw_rect(r, color)


static func _real_now() -> float:
	return Time.get_ticks_msec() / 1000.0
