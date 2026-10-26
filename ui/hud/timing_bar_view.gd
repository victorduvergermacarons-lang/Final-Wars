class_name TimingBarView
extends Control
## The local hero's timing bar (TimingBarDef): a big bar with its green and yellow
## zones and a cursor sweeping across it, under the ability's name; right-click
## while the cursor is on a zone. After the press it shows the result
## ("Perfect!", "Good", "Miss") for a moment. Options (the Escape menu's Gameplay
## test tab; saved on this computer):
## - where: under the hero, over the hero, or above the action bar
## - sliding: every bar has the same length and the cursor's speed depends on the
##   ability; off, the cursor always moves at the same speed and the bar's length
##   follows the ability (the full length = FULL_SECONDS), centred.

enum Place { BELOW_HERO, ACTION_BAR, ABOVE_HERO } # saved as ints: keep the order

## The bar above the action bar; by the hero it is half as long and half as tall.
const BAR := Vector2(440, 30)
## Sliding off: an ability of this many seconds fills BAR's length (shorter ones
## are shorter, longer ones longer, up to the screen's width).
const FULL_SECONDS := 3.0
## Space above the bar for the ability's name and the result.
const LABEL_HEIGHT := 26.0
## Gap between the hero's feet (or the action bar) and the bar.
const GAP := 34.0
## Over the hero: the bar's bottom sits this far (world pixels) above the feet,
## over the name and health bar, then GAP_ABOVE (screen pixels) higher.
const HEAD_WORLD := 56.0
const GAP_ABOVE := 6.0
const RESULT_SECONDS := 0.8
const BACK := Color(0.06, 0.06, 0.08, 0.88)
const EDGE := Color(0.92, 0.92, 0.92)
const GREEN := Color(0.2, 0.85, 0.3)
const YELLOW := Color(1.0, 0.85, 0.15)
const GRADE_TEXT := {"perfect": "Perfect!", "good": "Good", "miss": "Miss"}
const GRADE_COLOR := {"perfect": Color(1.0, 0.88, 0.3), "good": Color(0.35, 0.95, 0.45), "miss": Color(0.8, 0.8, 0.8)}

var hud: Hud
var place: int = Place.BELOW_HERO # Place
var sliding := true
## The bar being shown: {"bar": TimingBarDef, "start": float, "name": String}.
var _shown := {}
## After the press: {"grade", "at", "until" (real seconds)}.
var _result := {}


func _init(p_hud: Hud) -> void:
	hud = p_hud
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(_bar_size().x, _bar_size().y + LABEL_HEIGHT)
	visible = false


## The host judged the local hero's press (`at` < 0: no press in time).
func show_result(grade: String, at: float) -> void:
	_result = {"grade": grade, "at": at, "until": _real_now() + RESULT_SECONDS}


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
		var xform: Transform2D = view.get_canvas_transform()
		var feet_world: Vector2 = view.actor_screen_pos(hero)
		if place == Place.ABOVE_HERO:
			var head: Vector2 = xform * (feet_world + Vector2(0, -HEAD_WORLD))
			at = head + Vector2(-size.x / 2.0, -GAP_ABOVE - size.y)
		else:
			at = xform * feet_world + Vector2(-size.x / 2.0, GAP - LABEL_HEIGHT)
	return at.clamp(Vector2.ZERO, (screen - size).max(Vector2.ZERO))


func _draw() -> void:
	var bar: TimingBarDef = _shown.get("bar")
	if bar == null:
		return
	var seconds := maxf(bar.seconds, 0.01)
	var showing_result := not _result.is_empty()

	# Where the cursor is: sweeping, stopped where the player pressed, or at the end.
	var t := clampf(hud.session.render_time() - float(_shown.start), 0.0, seconds)
	var press: Dictionary = hud.client.timing_press
	if float(press.get("start", -1.0)) == float(_shown.start):
		t = clampf(float(press.at), 0.0, seconds)
	if showing_result:
		t = clampf(float(_result.at), 0.0, seconds) if float(_result.at) >= 0.0 else seconds

	var top := LABEL_HEIGHT
	var rect := Rect2(0, top, _bar_size().x, _bar_size().y)
	draw_rect(rect.grow(2), Color.BLACK)
	draw_rect(rect, BACK)
	for z in bar.zones:
		draw_rect(_zone_rect(z, seconds, top), GREEN)
	for z in bar.crit_zones:
		draw_rect(_zone_rect(z, seconds, top), YELLOW)
	draw_rect(rect, EDGE, false, 2.0)

	# The cursor: a tall white line with a dark outline, past the bar's edges.
	var x := t / seconds * _bar_size().x
	draw_rect(Rect2(x - 3, top - 7, 6, _bar_size().y + 14), Color.BLACK)
	draw_rect(Rect2(x - 1.5, top - 6, 3, _bar_size().y + 12), Color.WHITE)

	var font := get_theme_default_font()
	var text: String = _shown.name
	var color := Color.WHITE
	var font_size := 18
	if showing_result:
		text = GRADE_TEXT.get(_result.grade, "")
		color = GRADE_COLOR.get(_result.grade, Color.WHITE)
		font_size = 22
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var pos := Vector2((_bar_size().x - width) / 2.0, top - 6)
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 5, Color.BLACK)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _zone_rect(z: Vector2, seconds: float, top: float) -> Rect2:
	var from := clampf(z.x / seconds, 0.0, 1.0) * _bar_size().x
	var to := clampf((z.x + z.y) / seconds, 0.0, 1.0) * _bar_size().x
	return Rect2(from, top, maxf(to - from, 2.0), _bar_size().y)


static func _real_now() -> float:
	return Time.get_ticks_msec() / 1000.0


func _bar_size() -> Vector2:
	var s := BAR if place == Place.ACTION_BAR else BAR / 2.0
	var bar: TimingBarDef = _shown.get("bar")
	if not sliding and bar != null:
		s.x = minf(s.x * bar.seconds / FULL_SECONDS, get_viewport_rect().size.x - 20.0)
	return s
