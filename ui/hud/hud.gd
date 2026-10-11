class_name Hud
extends CanvasLayer
## In-game HUD: unit frames, action bar (with keybind mode), spellbook,
## character panel, death panel, mid-screen errors and a message log.

const ERROR_SECONDS := 2.0
const REASONS := {
	"out_of_range": "Out of range",
	"no_line_of_sight": "Target not in line of sight",
	"not_enough_mana": "Not enough mana",
	"on_cooldown": "Not ready yet",
	"invalid_target": "Invalid target",
	"in_combat": "You can't do that in combat",
	"blocked": "Can't go there",
	"occupied": "Someone is in the way",
	"unknown_ability": "You can't use that right now",
	"caster_dead": "You are dead",
	"bag_full": "Your bag is full",
	"cannot_equip": "You can't equip that there",
}

var session
var client: ClientState
var input: PlayerInput
var settings_path := SettingsStore.DEFAULT_PATH

var bind_mode := false
var hovered_slot := -1

var _root: Control
var _party: VBoxContainer
var _party_frames := {} # hero id -> UnitFrame
var inventory_window: InventoryWindow
var _spellbook: SpellbookPanel
var _character: CharacterSheet
var _death: PanelContainer
var _bind_button: Button
var _error: Label
var _log: Label


func setup(p_session, p_client: ClientState, p_input: PlayerInput, p_settings_path: String = SettingsStore.DEFAULT_PATH) -> void:
	session = p_session
	client = p_client
	input = p_input
	settings_path = p_settings_path
	SettingsStore.load_action_bar(client.action_bar, settings_path)
	InputActions.apply_action_bar_keys(client.action_bar)
	client.action_bar.changed.connect(_on_bar_changed)
	session.events_received.connect(_on_events)
	_build()


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	# Top-left: me, my target, then the rest of the party.
	var top := HBoxContainer.new()
	top.position = Vector2(10, 10)
	top.add_theme_constant_override("separation", 10)
	_root.add_child(top)
	var left := VBoxContainer.new()
	top.add_child(left)
	left.add_child(UnitFrame.new(self, func(): return session.local_hero(), 240, true))
	_party = VBoxContainer.new()
	left.add_child(_party)
	top.add_child(UnitFrame.new(self, func(): return session.get_actor(client.target_id), 220))

	# Bottom centre: action bar and panel buttons.
	var bottom := VBoxContainer.new()
	bottom.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bottom.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bottom.position.y -= 10
	_root.add_child(bottom)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_child(buttons)
	buttons.add_child(_small_button("Spellbook (P)", func(): _toggle(_spellbook)))
	buttons.add_child(_small_button("Character (C)", func(): _toggle(_character)))
	buttons.add_child(_small_button("Inventory (B)", func(): _toggle(inventory_window)))
	_bind_button = _small_button("Keybinds", func(): _set_bind_mode(not bind_mode))
	buttons.add_child(_bind_button)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 4)
	for i in ActionBarModel.SLOT_COUNT:
		bar.add_child(SlotButton.new(i, self))
	bottom.add_child(bar)

	# Panels on the right.
	var right := VBoxContainer.new()
	right.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	right.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	right.position = Vector2(-10, 10)
	_root.add_child(right)
	_character = CharacterSheet.new(self)
	_character.visible = false
	right.add_child(_character)
	inventory_window = InventoryWindow.new(self)
	inventory_window.visible = false
	right.add_child(inventory_window)
	_spellbook = SpellbookPanel.new(self)
	_spellbook.visible = false
	right.add_child(_spellbook)

	# Death panel and mid-screen error.
	_death = PanelContainer.new()
	_death.set_anchors_preset(Control.PRESET_CENTER)
	var death_box := VBoxContainer.new()
	_death.add_child(death_box)
	var dead_label := Label.new()
	dead_label.text = "You have died."
	dead_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	death_box.add_child(dead_label)
	death_box.add_child(_small_button("Release to graveyard (R)", func(): session.send_intent({"type": "release"})))
	var wait_label := Label.new()
	wait_label.text = "…or wait for an ally to resurrect you."
	death_box.add_child(wait_label)
	_death.visible = false
	_root.add_child(_death)
	_error = Label.new()
	_error.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_error.position.y = 140
	_error.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_error.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_error.add_theme_color_override("font_color", Color(1, 0.3, 0.25))
	_error.add_theme_color_override("font_outline_color", Color.BLACK)
	_error.add_theme_constant_override("outline_size", 5)
	_error.add_theme_font_size_override("font_size", 20)
	_error.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_error)

	# Bottom-left message log.
	_log = Label.new()
	_log.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_log.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_log.position = Vector2(10, -10)
	_log.add_theme_color_override("font_outline_color", Color.BLACK)
	_log.add_theme_constant_override("outline_size", 4)
	_log.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_log)


func _process(_delta: float) -> void:
	var hero: Hero = session.local_hero()
	if hero == null:
		return
	var ids: Array[StringName] = []
	for a in hero.available_abilities():
		ids.append(a.id)
	client.action_bar.auto_place(ids)
	_death.visible = not hero.alive
	_sync_party(hero)
	var age := Time.get_ticks_msec() / 1000.0 - client.error_at
	_error.text = client.error_text if age < ERROR_SECONDS else ""
	_error.modulate.a = clampf((ERROR_SECONDS - age) / 0.5, 0.0, 1.0)
	var lines: PackedStringArray = client.messages.duplicate()
	if bind_mode:
		lines.append("KEYBIND MODE: hover a slot and press a key. Esc or the Keybinds button to finish.")
	lines.append("WASD move · click/Tab target · Esc clear target · R release · wheel zoom")
	_log.text = "\n".join(lines)


func _sync_party(me: Hero) -> void:
	var present := {}
	for a in session.actors():
		if a is Hero and a.id != me.id:
			present[a.id] = true
			if not _party_frames.has(a.id):
				var id: int = a.id
				var frame := UnitFrame.new(self, func(): return session.get_actor(id), 200)
				_party_frames[id] = frame
				_party.add_child(frame)
	for id in _party_frames.keys():
		if not present.has(id):
			_party_frames[id].queue_free()
			_party_frames.erase(id)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"toggle_spellbook"):
		_toggle(_spellbook)
	elif event.is_action_pressed(&"toggle_character"):
		_toggle(_character)
	elif event.is_action_pressed(&"toggle_inventory"):
		_toggle(inventory_window)


## Keybind mode grabs key presses before anything else sees them.
func _input(event: InputEvent) -> void:
	if not bind_mode or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	get_viewport().set_input_as_handled()
	var key: int = event.physical_keycode
	if key == KEY_ESCAPE:
		_set_bind_mode(false)
	elif hovered_slot >= 0 and not client.action_bar.set_key(hovered_slot, key):
		client.error("%s is used for something else" % OS.get_keycode_string(key))


func _set_bind_mode(on: bool) -> void:
	bind_mode = on
	_bind_button.text = "Done binding" if on else "Keybinds"


func _toggle(panel: Control) -> void:
	panel.visible = not panel.visible


func _on_bar_changed() -> void:
	InputActions.apply_action_bar_keys(client.action_bar)
	SettingsStore.save_action_bar(client.action_bar, settings_path)


func _on_events(events: Array) -> void:
	var me: int = session.local_hero_id
	for e in events:
		match e.type:
			"joined":
				client.say("%s joined the game." % e.name)
			"left":
				client.say("%s left the game." % e.name)
		if e.get("target", -2) != me:
			continue
		match e.type:
			"rejected":
				if e.reason != "not_ready":
					client.error(REASONS.get(e.reason, String(e.reason).capitalize()))
			"level_up":
				client.say("You reached level %d!" % e.level)
			"mastered":
				var a: AbilityDef = ContentDB.abilities.get(StringName(e.ability))
				client.say("You mastered %s! It stays usable without its item." % (a.display_name if a else e.ability))
			"death":
				client.say("You died.")
			"release":
				client.say("You return at the graveyard.")
			"resurrect":
				client.say("You have been resurrected.")


func _small_button(text: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(on_press)
	return b
