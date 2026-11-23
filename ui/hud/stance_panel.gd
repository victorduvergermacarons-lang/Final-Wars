class_name StancePanel
extends Control
## Above the action bar while a bending stance is held (stance rework, 2026-11-23):
## the element and stance number, then its four branch abilities on keys 1-4, each
## with its icon, cooldown sweep and key; greyed when it can't be used yet (not
## learned, locked or not in the game). Hidden out of a stance.

const SLOT := Vector2(44, 44)
const GAP := 6.0
const TITLE_W := 150.0

var hud: Hud
var _font: Font


func _init(p_hud: Hud) -> void:
	hud = p_hud
	_font = ThemeDB.fallback_font
	custom_minimum_size = Vector2(TITLE_W + 4 * (SLOT.x + GAP), SLOT.y + 4)
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	var hero: Hero = hud.session.local_hero() if hud.session != null else null
	visible = hero != null and hero.stance > 0
	if visible:
		queue_redraw()


## The four branch abilities of the stance held (null where the sheet has none).
static func branches(hero: Hero) -> Array:
	var out := []
	for b in range(1, 5):
		out.append(WorldSim.stance_ability(ContentDB.abilities, hero.stance_tree, hero.stance, b))
	return out


func _draw() -> void:
	var hero: Hero = hud.session.local_hero()
	if hero == null or hero.stance <= 0:
		return
	var now: float = hud.session.now()
	var c: Color = SlotButton.STANCE_COLORS.get(hero.stance_tree, Color.GRAY)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.05, 0.07, 0.75))
	draw_rect(Rect2(Vector2.ZERO, size), c, false, 2.0)
	_text("%s" % hero.stance_tree, Vector2(10, 20), 16, c.lightened(0.4))
	_text("Stance %d  ·  Shift leaves" % hero.stance, Vector2(10, 40), 12, Color(0.85, 0.85, 0.9))
	var list := branches(hero)
	for i in list.size():
		var def: AbilityDef = list[i]
		var r := Rect2(Vector2(TITLE_W + i * (SLOT.x + GAP), 2), SLOT)
		draw_rect(r, Color(0.12, 0.13, 0.17))
		draw_rect(r, c.darkened(0.2), false, 1.0)
		if def != null:
			var known := hero.find_ability(def.id)
			var icon := Icons.of_ability(def)
			if icon != null:
				Icons.draw_fitted(self, icon, r.grow(-2.0), Color.WHITE if known != null else Color(1, 1, 1, 0.45), 8,
						known == null)
			else:
				_text(def.display_name.left(5), r.position + Vector2(3, 26), 11, Color.WHITE)
			if known != null:
				var frac := maxf(hero.cooldowns.ability_fraction(known.cooldown_key(), now),
						hero.cooldowns.gcd_fraction(now) if known.on_gcd else 0.0)
				if frac > 0.0:
					_sweep(r, frac)
		_text(str(i + 1), r.position + Vector2(r.size.x - 10, 12), 11, Color(0.9, 0.9, 0.95))


func _sweep(rect: Rect2, fraction: float) -> void:
	var cen := rect.get_center()
	var rad := minf(rect.size.x, rect.size.y) * 0.5
	var pts := PackedVector2Array([cen])
	for k in 25:
		var ang := -PI * 0.5 + TAU * fraction * k / 24.0
		pts.append(cen + Vector2(cos(ang), sin(ang)) * rad)
	draw_colored_polygon(pts, Color(0, 0, 0, 0.6))


func _text(t: String, pos: Vector2, font_size: int, color: Color) -> void:
	draw_string_outline(_font, pos, t, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 3, Color.BLACK)
	draw_string(_font, pos, t, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
