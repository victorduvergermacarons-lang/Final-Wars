class_name SpellbookPanel
extends PanelContainer
## Every ability the hero can use right now, with mastery progress. Drag an
## entry onto the action bar.

var hud: Hud
var _list: VBoxContainer
var _shown_key := ""


func _init(p_hud: Hud) -> void:
	hud = p_hud
	custom_minimum_size = Vector2(320, 0)
	var box := VBoxContainer.new()
	add_child(box)
	var title := Label.new()
	title.text = "Spellbook (P) — drag onto the action bar"
	box.add_child(title)
	_list = VBoxContainer.new()
	box.add_child(_list)


func _process(_delta: float) -> void:
	if not visible:
		return
	var hero: Hero = hud.session.local_hero()
	if hero == null:
		return
	# Rebuild only when the content changes.
	var parts: PackedStringArray = []
	for a in hero.available_abilities():
		parts.append("%s:%d:%s" % [a.id, hero.ap.get(a.id, 0), hero.is_mastered(a.id)])
	var key := ",".join(parts)
	if key == _shown_key:
		return
	_shown_key = key
	for c in _list.get_children():
		c.queue_free()
	for a in hero.available_abilities():
		var progress := "Mastered" if hero.is_mastered(a.id) else (
				"AP %d / %d" % [hero.ap.get(a.id, 0), a.ap_to_master] if a.ap_to_master > 0 else "")
		_list.add_child(_Entry.new(a, "%s   %s" % [a.display_name, progress]))


class _Entry:
	extends Button
	var ability: AbilityDef

	func _init(p_ability: AbilityDef, label: String) -> void:
		ability = p_ability
		text = label
		alignment = HORIZONTAL_ALIGNMENT_LEFT
		focus_mode = Control.FOCUS_NONE
		tooltip_text = SlotButton._tooltip(p_ability)

	func _get_drag_data(_at: Vector2) -> Variant:
		var preview := Label.new()
		preview.text = ability.display_name
		set_drag_preview(preview)
		return {"ability": ability.id}
