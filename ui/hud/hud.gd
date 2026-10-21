class_name Hud
extends CanvasLayer

## The player clicked "Leave game" (save and return to the main menu).
signal leave_requested
## In-game HUD: unit frames, action bar (with keybind mode), spellbook,
## character panel, death panel, mid-screen errors and a message log.

const ERROR_SECONDS := 2.0
## Message log width: fits left of the centred action bar at 1280 px.
const LOG_WIDTH := 310.0
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
	"too_far": "You're too far away",
	"no_npc": "There's no one to talk to here",
	"no_loot": "That loot is gone",
	"not_enough_gold": "You don't have enough gold",
	"cant_sell": "The trader won't buy that",
	"not_sold_here": "That isn't sold here",
	"not_usable": "You can't use that",
	"no_quest": "You don't have that quest",
	"wrong_npc": "That's not who you need to talk to",
	"quest_active": "You're already on that quest",
	"quest_done": "You've already done that quest",
	"level_too_low": "You need a higher level for that quest",
	"prerequisite": "You need to finish an earlier quest first",
	"quest_not_ready": "That quest isn't finished yet",
	"choose_reward": "Choose a reward first",
}

var session
var client: ClientState
var input: PlayerInput
var settings_path := SettingsStore.DEFAULT_PATH

var bind_mode := false
var hovered_slot := -1

var _root: Control
## The menu book; open menu windows are on its pages.
var book: BookView
## The menu open in the book (one at a time; each fills both pages), or null.
var _open_menu: Control
var _party: VBoxContainer
var _party_frames := {} # hero id -> UnitFrame
var inventory_window: InventoryWindow
var dialogue: DialogueBox
var loot_window: LootWindow
var vendor_window: VendorWindow
var quest_log: QuestLogWindow
var _tracker: RichTextLabel
var _page_label: Label
var _spellbook: SpellbookPanel
var trees_window: AbilityTreeWindow
var console: DebugConsole
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

	# The menu book, under the rest of the HUD (frames, action bar and buttons stay
	# usable on top). Menu windows are written on its pages (_update_book).
	book = BookView.new()
	book.visible = false
	book.close_requested.connect(close_menus)
	_root.add_child(book)

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
	buttons.add_child(_small_button("Trees (T)", func(): _toggle(trees_window)))
	buttons.add_child(_small_button("Character (C)", func(): _toggle(_character)))
	buttons.add_child(_small_button("Inventory (B)", func(): _toggle(inventory_window)))
	buttons.add_child(_small_button("Quests (L)", func(): _toggle(quest_log)))
	_bind_button = _small_button("Keybinds", func(): _set_bind_mode(not bind_mode))
	buttons.add_child(_bind_button)
	buttons.add_child(_small_button("Leave game", func(): leave_requested.emit()))
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 4)
	for i in ActionBarModel.SLOT_COUNT:
		bar.add_child(SlotButton.new(i, self))
	bottom.add_child(bar)

	# Bottom-right: which action bar page is shown (Shift+1–6, or the arrows).
	var pager := PanelContainer.new()
	pager.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	pager.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	pager.grow_vertical = Control.GROW_DIRECTION_BEGIN
	pager.position = Vector2(-10, -10)
	pager.tooltip_text = "Action bar page. Shift+1 to Shift+%d switch pages." % ActionBarModel.PAGE_COUNT
	_root.add_child(pager)
	var pager_box := VBoxContainer.new()
	pager_box.alignment = BoxContainer.ALIGNMENT_CENTER
	pager.add_child(pager_box)
	var pager_title := Label.new()
	pager_title.text = "Action bar"
	pager_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pager_title.add_theme_font_size_override("font_size", 12)
	pager_box.add_child(pager_title)
	var pager_row := HBoxContainer.new()
	pager_row.alignment = BoxContainer.ALIGNMENT_CENTER
	pager_box.add_child(pager_row)
	pager_row.add_child(_small_button("<", func(): client.action_bar.set_page(client.action_bar.page - 1)))
	_page_label = Label.new()
	_page_label.custom_minimum_size = Vector2(34, 0)
	_page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_page_label.add_theme_font_size_override("font_size", 28)
	_page_label.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	pager_row.add_child(_page_label)
	pager_row.add_child(_small_button(">", func(): client.action_bar.set_page(client.action_bar.page + 1)))
	var pager_hint := Label.new()
	pager_hint.text = "Shift+1–%d" % ActionBarModel.PAGE_COUNT
	pager_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pager_hint.add_theme_font_size_override("font_size", 11)
	pager_hint.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	pager_box.add_child(pager_hint)

	# Menus fill the book's two pages, one at a time (see _update_book).
	_character = CharacterSheet.new(self)
	_character.visible = false
	inventory_window = InventoryWindow.new(self)
	inventory_window.visible = false
	loot_window = LootWindow.new(self)
	vendor_window = VendorWindow.new(self)
	_spellbook = SpellbookPanel.new(self)
	_spellbook.visible = false
	quest_log = QuestLogWindow.new(self)
	quest_log.visible = false
	for w in [_character, inventory_window, loot_window, vendor_window, _spellbook, quest_log]:
		book.spread.add_child(w)

	# Debug console (`), top centre.
	console = DebugConsole.new(self)
	console.visible = false
	console.set_anchors_preset(Control.PRESET_CENTER_TOP)
	console.grow_horizontal = Control.GROW_DIRECTION_BOTH
	console.position.y += 80
	_root.add_child(console)

	# Ability trees: a big window across both pages.
	trees_window = AbilityTreeWindow.new(self)
	trees_window.visible = false
	book.spread.add_child(trees_window)

	# Quest tracker on the right edge.
	_tracker = RichTextLabel.new()
	_tracker.bbcode_enabled = true
	_tracker.fit_content = true
	_tracker.scroll_active = false
	_tracker.custom_minimum_size = Vector2(300, 0)
	_tracker.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	_tracker.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_tracker.position.x -= 10
	_tracker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# A note on paper, in ink like the book (QuestText's colours are for paper).
	_tracker.theme = UiPalette.paper_theme()
	var tracker_bg := UiPalette.paper_panel(8)
	tracker_bg.bg_color = Color(UiPalette.PAPER, 0.92)
	_tracker.add_theme_stylebox_override("normal", tracker_bg)
	_root.add_child(_tracker)
	_root.move_child(_tracker, 0) # behind every window

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
	dialogue = DialogueBox.new(self)
	dialogue.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	dialogue.grow_horizontal = Control.GROW_DIRECTION_BOTH
	dialogue.grow_vertical = Control.GROW_DIRECTION_BEGIN
	dialogue.position.y -= 130
	_root.add_child(dialogue)
	dialogue.opened.connect(_on_dialogue_opened)
	dialogue.closed.connect(func(): vendor_window.close())
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
	# Wraps to the space left of the action bar; placed from the bottom each frame.
	_log = Label.new()
	_log.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_log.custom_minimum_size = Vector2(LOG_WIDTH, 0)
	_log.add_theme_color_override("font_outline_color", Color.BLACK)
	_log.add_theme_constant_override("outline_size", 4)
	_log.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_log)


func _process(_delta: float) -> void:
	_update_book()
	var hero: Hero = session.local_hero()
	if hero == null:
		return
	var ids: Array[StringName] = []
	for a in hero.available_abilities():
		ids.append(a.id)
	client.action_bar.auto_place(ids)
	_death.visible = not hero.alive
	_sync_party(hero)
	_page_label.text = str(client.action_bar.page + 1)
	_update_quest_markers(hero)
	_tracker.text = QuestText.tracker_bbcode(hero, ContentDB.quests)
	_tracker.visible = _tracker.text != "" and not _tracker_covered()
	var age := Time.get_ticks_msec() / 1000.0 - client.error_at
	_error.text = client.error_text if age < ERROR_SECONDS else ""
	_error.modulate.a = clampf((ERROR_SECONDS - age) / 0.5, 0.0, 1.0)
	var lines: PackedStringArray = client.messages.duplicate()
	if bind_mode:
		lines.append("KEYBIND MODE: hover a slot and press a key. Esc or the Keybinds button to finish.")
	lines.append("WASD move · E talk · click/Tab target · Esc clear target · R release · T trees · wheel zoom")
	_log.text = "\n".join(lines)
	_log.size = Vector2(LOG_WIDTH, 0)
	var view_size := get_viewport().get_visible_rect().size
	_log.position = Vector2(10, view_size.y - _log.get_combined_minimum_size().y - 10)


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
	if event.is_action_pressed(&"toggle_console"):
		if console.visible:
			console.close()
		else:
			console.open()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"toggle_spellbook"):
		_toggle(_spellbook)
	elif event.is_action_pressed(&"toggle_trees"):
		_toggle(trees_window)
	elif event.is_action_pressed(&"toggle_character"):
		_toggle(_character)
	elif event.is_action_pressed(&"toggle_inventory"):
		_toggle(inventory_window)
	elif event.is_action_pressed(&"toggle_quest_log"):
		_toggle(quest_log)


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


## The windows written in the book.
func _book_windows() -> Array[Control]:
	return [_character, inventory_window, loot_window, vendor_window, _spellbook, quest_log, trees_window]


## Shows the book while a menu is open. Each menu fills both pages, so one is
## open at a time: opening another closes the one before.
func _update_book() -> void:
	var fresh: Array[Control] = []
	for w in _book_windows():
		if w.visible and w != _open_menu:
			fresh.append(w)
	if not fresh.is_empty():
		_open_menu = fresh.back()
	elif _open_menu != null and not _open_menu.visible:
		_open_menu = null
	for w in _book_windows():
		if w.visible and w != _open_menu:
			_close_menu(w)
	book.visible = _open_menu != null
	if book.visible:
		book.fit_pages()


## Closes every menu in the book (its Close button).
func close_menus() -> void:
	for w in _book_windows():
		_close_menu(w)


func _close_menu(w: Control) -> void:
	if w == vendor_window:
		vendor_window.close()
	else:
		w.visible = false


func _on_bar_changed() -> void:
	InputActions.apply_action_bar_keys(client.action_bar)
	SettingsStore.save_action_bar(client.action_bar, settings_path)


func _on_events(events: Array) -> void:
	var me: int = session.local_hero_id
	for e in events:
		if e.type == "debug" and e.get("target", -1) == me:
			console.show_result(e)
			continue
		if e.type == "rejected" and e.get("intent", "") == "debug" and e.get("target", -1) == me:
			console.show_result({"ok": false, "text": "The host doesn't allow debug commands (debug builds only)."})
			continue
		match e.type:
			"joined":
				client.say("%s joined the game." % e.name)
			"left":
				client.say("%s left the game." % e.name)
			"world_flag":
				if e.get("text", "") != "":
					client.say(e.text)
			"enrage":
				var who = session.get_actor(e.get("source", -1))
				var buff: BuffDef = ContentDB.buffs.get(e.get("buff", &""))
				if who != null and buff != null:
					client.say("%s flies into %s!" % [who.display_name, buff.display_name])
			"zone_reset":
				client.say("The shrine glows: every creature returns to its pen and lingering effects fade.")
		if e.get("target", -2) != me:
			continue
		var quest_msg := QuestText.event_message(e, ContentDB.quests)
		if quest_msg != "":
			client.say(quest_msg)
			if e.type in ["quest_accepted", "quest_completed"]:
				var talking := dialogue.current_npc()
				if dialogue.visible and talking != null:
					dialogue.open(talking) # back to the main page with fresh options
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
			"loot":
				var parts: PackedStringArray = []
				if e.gold > 0:
					parts.append("%d gold" % e.gold)
				for pair in e.items:
					var item: ItemDef = ContentDB.items.get(StringName(str(pair[0])))
					parts.append((item.display_name if item else str(pair[0])) + (" ×%d" % pair[1] if pair[1] > 1 else ""))
				client.say("You loot " + ", ".join(parts) + ".")
				if e.left >= 0:
					client.error("Your bag is full — the rest waits 60 s in the loot window")
			"buy":
				var bought: ItemDef = ContentDB.items.get(StringName(str(e.item)))
				client.say("You buy %s for %d gold." % [bought.display_name if bought else e.item, e.gold])
			"sell":
				var sold: ItemDef = ContentDB.items.get(StringName(str(e.item)))
				client.say("You sell %s%s for %d gold." % [sold.display_name if sold else e.item,
						" ×%d" % e.count if e.count > 1 else "", e.gold])
			"dialogue":
				var npc: Actor = session.get_actor(e.npc)
				if npc is Npc:
					dialogue.open(npc)


## Whether an open window overlaps the quest tracker (then the tracker hides,
## so its text never mixes with a menu's).
func _tracker_covered() -> bool:
	if book.visible:
		return true
	return dialogue.visible and dialogue.get_global_rect().intersects(_tracker.get_global_rect())


## "!" / "?" over quest givers, for the local hero.
func _update_quest_markers(hero: Hero) -> void:
	client.npc_markers.clear()
	for npc in ContentDB.npcs.values():
		var m := QuestLog.npc_marker(hero, ContentDB.quests, npc.id)
		if m != "":
			client.npc_markers[npc.id] = m


## Adds the NPC's extra conversation options (shop, quests…).
func _on_dialogue_opened(npc: Npc) -> void:
	QuestDialogue.add_options(self, npc)
	if not npc.def.sells.is_empty():
		dialogue.add_option("Browse goods", func(): vendor_window.open(npc)) # its right page is your bag


func _small_button(text: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(on_press)
	return b
