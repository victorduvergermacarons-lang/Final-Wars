class_name CharacterPanel
extends PanelContainer
## Equipment (one dropdown per slot), stats and ability progress. Gear changes
## are sent as intents; the host refuses them in combat.

const STAT_NAMES := ["HP", "Mana", "Physical Attack", "Magic Attack", "Physical Defense",
	"Magic Defense", "Crit Rate %", "Crit Damage %", "Speed", "Accuracy", "Evasion", "Jump"]

var hud: Hud
var _pickers: Array[OptionButton] = []
var _picker_items: Array = [] # per slot: Array of item ids (index 0 = none)
var _stats: Label
var _shown_key := ""


func _init(p_hud: Hud) -> void:
	hud = p_hud
	custom_minimum_size = Vector2(320, 0)
	var box := VBoxContainer.new()
	add_child(box)
	var title := Label.new()
	title.text = "Character (C)"
	box.add_child(title)
	for slot in EquipSlot.COUNT:
		var row := HBoxContainer.new()
		var label := Label.new()
		label.text = EquipSlot.NAMES[slot]
		label.custom_minimum_size = Vector2(100, 0)
		row.add_child(label)
		var picker := OptionButton.new()
		picker.focus_mode = Control.FOCUS_NONE
		picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		picker.item_selected.connect(_on_pick.bind(slot))
		row.add_child(picker)
		box.add_child(row)
		_pickers.append(picker)
		_picker_items.append([])
	_stats = Label.new()
	box.add_child(_stats)


func _process(_delta: float) -> void:
	if not visible:
		return
	var hero: Hero = hud.session.local_hero()
	if hero == null:
		return
	_refresh_pickers(hero)
	var s := hero.current_stats(hud.session.now())
	var lines: PackedStringArray = []
	for id in Stat.all():
		lines.append("%s: %s" % [STAT_NAMES[id], snappedf(s.get_stat(id), 0.1)])
	lines.append("")
	lines.append("Ability progress:")
	var ids := {}
	for item in hero.inventory:
		for a in item.teaches:
			ids[a.id] = a
	for id in ids:
		var a: AbilityDef = ids[id]
		lines.append("  %s: %s" % [a.display_name, "mastered" if hero.is_mastered(id)
				else "%d / %d AP" % [hero.ap.get(id, 0), a.ap_to_master]])
	_stats.text = "\n".join(lines)


func _refresh_pickers(hero: Hero) -> void:
	var parts: PackedStringArray = []
	for item in hero.inventory:
		parts.append(String(item.id))
	for slot in EquipSlot.COUNT:
		var e := hero.equipped_in(slot)
		parts.append(String(e.id) if e != null else "-")
	var key := ",".join(parts)
	if key == _shown_key:
		return
	_shown_key = key
	for slot in EquipSlot.COUNT:
		var picker := _pickers[slot]
		picker.clear()
		var ids: Array = [&""]
		picker.add_item("(none)")
		for item in hero.inventory:
			if EquipSlot.slots_for(item.slot).has(slot) and not ids.has(item.id):
				picker.add_item(item.display_name)
				ids.append(item.id)
		_picker_items[slot] = ids
		var equipped := hero.equipped_in(slot)
		picker.select(ids.find(equipped.id) if equipped != null else 0)


func _on_pick(index: int, slot: int) -> void:
	var id: StringName = _picker_items[slot][index]
	if id == &"":
		hud.session.send_intent({"type": "unequip", "slot": slot})
	else:
		hud.session.send_intent({"type": "equip", "item": id, "slot": slot})
	_shown_key = "" # re-sync with what the host actually does
