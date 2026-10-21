class_name SpellbookPanel
extends BookSpread
## Every ability the hero can use right now, with mastery progress, written
## across the menu book: the first half of the list on the left page, the rest
## on the right. Drag an entry onto the action bar.

var hud: Hud
var _lists: Array[VBoxContainer] = []
var _shown_key := ""


func _init(p_hud: Hud) -> void:
	super()
	hud = p_hud
	# Lower on both pages, clear of their darker top border; the right page's list
	# starts level with the left one's, under the title.
	left.add_child(BookSpread.spacer(TOP_GAP))
	left.add_child(BookSpread.title("Spellbook"))
	right.add_child(BookSpread.spacer(TOP_GAP))
	right.add_child(BookSpread.title(" ")) # a blank line as tall as the title
	for page in [left, right]:
		var list := VBoxContainer.new()
		page.add_child(list)
		_lists.append(list)


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
	for list in _lists:
		for c in list.get_children():
			c.queue_free()
	var abilities := hero.available_abilities()
	# The left page also holds the title, so it takes a little less.
	var on_left := maxi(1, (abilities.size() + 1) / 2 - 1) if abilities.size() > 2 else abilities.size()
	for i in abilities.size():
		var a: AbilityDef = abilities[i]
		var progress := "Mastered" if hero.is_mastered(a.id) else (
				"AP %d / %d" % [hero.ap.get(a.id, 0), a.ap_to_master] if a.ap_to_master > 0 else "")
		_lists[0 if i < on_left else 1].add_child(_Entry.new(a, "%s   %s" % [a.display_name, progress]))


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
