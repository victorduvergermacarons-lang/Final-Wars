class_name RollWindow
extends VBoxContainer
## Boss item rolls: one card per roll you may join (LootRolls, sent in snapshots):
## the item (rarity colour, full tooltip), the boss, a bar running down the
## PartyPlayDef.roll_seconds, your bad-luck bonus, and Need / Greed / Pass. A card
## goes once you have chosen or the roll is settled.

var hud: Hud
var _cards := {} # roll id -> PanelContainer
## Rolls this player already answered (hidden at once, before the host confirms).
var answered := {}


func _init(p_hud: Hud) -> void:
	hud = p_hud
	add_theme_constant_override("separation", 8)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	refresh()


func refresh() -> void:
	var hero: Hero = hud.session.local_hero()
	var live := {}
	if hero != null:
		for r in hud.session.loot_rolls():
			if not r.eligible.has(hero.id) or r.chosen.has(hero.id) or answered.has(r.id):
				continue
			live[r.id] = true
			if not _cards.has(r.id):
				_cards[r.id] = _card(r)
				add_child(_cards[r.id])
			_update(_cards[r.id], r, hero)
	for id in _cards.keys():
		if not live.has(id):
			_cards[id].queue_free()
			_cards.erase(id)
	visible = not _cards.is_empty()


## The ids of the rolls showing (tests).
func showing() -> Array:
	return _cards.keys()


## Answers roll `id` (the buttons; tests).
func choose(id: int, choice: String) -> void:
	answered[id] = true
	hud.session.send_intent({"type": "roll", "roll": id, "choice": choice})
	refresh()


func _card(r: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.theme = UiPalette.paper_theme()
	panel.add_theme_stylebox_override("panel", UiPalette.paper_panel(8))
	panel.custom_minimum_size = Vector2(380, 0)
	var box := VBoxContainer.new()
	panel.add_child(box)
	var item: ItemDef = ContentDB.items.get(StringName(r.item))
	var title: Control = ItemLabel.new(hud, item) if item != null else Label.new()
	box.add_child(title)
	var from := Label.new()
	from.name = "From"
	from.add_theme_font_size_override("font_size", 14)
	box.add_child(from)
	var bar := ProgressBar.new()
	bar.name = "Time"
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 8)
	var fill := StyleBoxFlat.new()
	fill.bg_color = UiPalette.LEATHER_DARK
	bar.add_theme_stylebox_override("fill", fill)
	box.add_child(bar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	for c in [["Need", "need"], ["Greed", "greed"], ["Pass", "pass"]]:
		var b := Button.new()
		b.text = c[0]
		b.name = c[1]
		b.custom_minimum_size = Vector2(100, 0)
		var id: int = r.id
		var choice: String = c[1]
		b.pressed.connect(func(): choose(id, choice))
		row.add_child(b)
	return panel


func _update(card: PanelContainer, r: Dictionary, hero: Hero) -> void:
	var left: float = maxf(float(r.ends_at) - hud.session.now(), 0.0)
	var total: float = hud.session.rules().party_play.roll_seconds
	var bar: ProgressBar = card.find_child("Time", true, false)
	bar.max_value = total
	bar.value = left
	var from: Label = card.find_child("From", true, false)
	from.text = "From %s  ·  %d s  ·  your bonus +%d" % [r.boss, ceili(left), hero.loot_bonus]
