class_name LearningRow
extends HBoxContainer
## The learning slot with a label: what's being learned and its AP. Used in the
## inventory window and on the character sheet.

var hud: Hud
var _label: Label


func _init(p_hud: Hud) -> void:
	hud = p_hud
	add_child(ItemSlotView.new(hud, ItemSlotView.Kind.LEARNING, 0))
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 12)
	_label.add_theme_color_override("font_color", ItemSlotView.LEARNING_COLOR)
	_label.custom_minimum_size = Vector2(130, 0)
	add_child(_label)


func _process(_delta: float) -> void:
	if is_visible_in_tree() and hud.session != null:
		_label.text = text_for(hud.session.local_hero())


## "Learning: Fire Punch, AP 10 / 20", or a hint when the slot is empty.
static func text_for(hero: Hero) -> String:
	if hero == null or hero.learning_item == null:
		return "Learning: nothing.\nDrop a scroll or your\nweapon here."
	var ability := hero.learning_item.tree_ability()
	if ability == null:
		return "Learning: %s" % hero.learning_item.display_name
	return "Learning: %s\nAP %d / %d" % [ability.display_name, hero.ap.get(ability.id, 0), ability.ap_to_master]
