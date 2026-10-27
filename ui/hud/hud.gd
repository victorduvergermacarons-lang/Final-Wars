class_name Hud
extends CanvasLayer

## The player clicked "Leave game" (save and return to the main menu).
signal leave_requested
## In-game HUD: unit frames, action bar (with keybind mode), the menu book, the
## shop sheet, the quest tracker, death panel, mid-screen errors, and the Escape
## menu (message log, controls, keybinds, leave game).

const ERROR_SECONDS := 2.0
## The quest tracker on the right: its width and text size.
const TRACKER_WIDTH := 260.0
const TRACKER_FONT_SIZE := 15
const REASONS := {
	"debug_disabled": "The host doesn't allow test settings (debug builds only)",
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
	"dungeon_needs_quest": "You need the quest for this place first",
	"dungeon_party_too_small": "You need a party of %d to go in",
}

var session
var client: ClientState
var input: PlayerInput
var settings_path := SettingsStore.DEFAULT_PATH

var bind_mode := false
var hovered_slot := -1
## The bag item under the mouse, and the item being dragged (ItemSlotView): the
## equipment slots it would go in light up.
var hovered_item: ItemDef
var dragged_item: ItemDef

var _root: Control
## The menu book; open menu windows are on its pages.
var book: BookView
## The menu open in the book (one at a time; each fills both pages), or null.
var _open_menu: Control
var _party: VBoxContainer
var _party_frames := {} # hero id -> UnitFrame
var inventory_window: InventoryWindow
var dialogue: DialogueBox
## Co-op: quests a party member just accepted, offered to you.
var quest_prompt: QuestPrompt
var loot_window: LootWindow
var vendor_window: VendorWindow
var quest_log: QuestLogWindow
var _tracker: RichTextLabel
var _tracker_panel: PanelContainer
var _tracker_fold: Button
var _tracker_dragging := false
## The Escape menu (log, controls, keybinds, leave game).
var game_menu: GameMenu
var timing_bar: TimingBarView
var _action_bar: Control
var _page_label: Label
var _spellbook: SpellbookPanel
var trees_window: AbilityTreeWindow
var console: DebugConsole
var _character: CharacterSheet
var _death: PanelContainer
var _bind_banner: Label
var _error: Label


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


## Where the action bar is on screen (the timing bar can sit above it).
func action_bar_rect() -> Rect2:
	return _action_bar.get_global_rect()


## Puts the timing bar under the hero or above the action bar, and saves the choice.
func set_timing_bar_place(place: int) -> void:
	timing_bar.place = place
	SettingsStore.save_ui("timing_bar_place", place, settings_path)


## The timing bar's mode (TimingBarView.Mode: the bar's length follows the ability,
## or zones slide toward a fixed hit line), and saves the choice.
func set_timing_bar_mode(mode: int) -> void:
	timing_bar.mode = mode
	SettingsStore.save_ui("timing_bar_mode", mode, settings_path)


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
	book.turn_requested.connect(_turn_page)
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

	# Bottom centre: the action bar (menus open with their keys; Keybinds and Leave
	# game are in the Escape menu), with a banner above it in keybind mode.
	var bottom := VBoxContainer.new()
	bottom.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bottom.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bottom.position.y -= 10
	_root.add_child(bottom)
	_bind_banner = Label.new()
	_bind_banner.text = "Keybind mode: hover a slot and press a key. Esc to finish."
	_bind_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bind_banner.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	_bind_banner.add_theme_color_override("font_outline_color", Color.BLACK)
	_bind_banner.add_theme_constant_override("outline_size", 4)
	_bind_banner.visible = false
	bottom.add_child(_bind_banner)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 4)
	for i in ActionBarModel.SLOT_COUNT:
		bar.add_child(SlotButton.new(i, self))
	bottom.add_child(bar)
	_action_bar = bar

	# The local hero's timing bar (right-click on its zones), under the hero or
	# above the action bar.
	timing_bar = TimingBarView.new(self)
	var saved_place := int(SettingsStore.load_ui("timing_bar_place", TimingBarView.Place.BELOW_HERO, settings_path))
	timing_bar.place = saved_place if saved_place in TimingBarView.Place.values() else TimingBarView.Place.BELOW_HERO
	var saved_mode := int(SettingsStore.load_ui("timing_bar_mode", TimingBarView.Mode.LENGTH, settings_path))
	timing_bar.mode = saved_mode if saved_mode in TimingBarView.Mode.values() else TimingBarView.Mode.LENGTH
	_root.add_child(timing_bar)

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
	for w in [_character, inventory_window, loot_window, _spellbook, quest_log]:
		book.spread.add_child(w)
	# The shop is a sheet of its own, above the book, so it stays open beside
	# your inventory.
	_root.add_child(vendor_window)

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

	# Quest tracker on the right edge: a paper note in ink (QuestText's colours are
	# for paper) with a button that folds it down to its heading.
	_tracker_panel = PanelContainer.new()
	_tracker_panel.theme = UiPalette.paper_theme()
	var tracker_bg := UiPalette.paper_panel(8)
	tracker_bg.bg_color = Color(UiPalette.PAPER, 0.92)
	_tracker_panel.add_theme_stylebox_override("panel", tracker_bg)
	_tracker_panel.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	_tracker_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_tracker_panel.position.x -= 10
	_root.add_child(_tracker_panel)
	_root.move_child(_tracker_panel, 0) # behind every window
	var tracker_box := VBoxContainer.new()
	_tracker_panel.add_child(tracker_box)
	# The heading is its handle: drag it to move the tracker anywhere.
	var tracker_head := HBoxContainer.new()
	tracker_head.mouse_filter = Control.MOUSE_FILTER_STOP
	tracker_head.mouse_default_cursor_shape = Control.CURSOR_MOVE
	tracker_head.tooltip_text = "Drag to move the quest list"
	tracker_head.gui_input.connect(_on_tracker_drag)
	tracker_box.add_child(tracker_head)
	var tracker_title := Label.new()
	tracker_title.text = "Quests"
	tracker_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tracker_title.add_theme_font_size_override("font_size", 16)
	tracker_title.add_theme_color_override("font_color", UiPalette.LEATHER_DARK)
	tracker_head.add_child(tracker_title)
	_tracker_fold = _small_button("–", func(): _fold_tracker(_tracker.visible))
	_tracker_fold.tooltip_text = "Fold or unfold the quest list"
	_tracker_fold.add_theme_font_size_override("font_size", 14)
	tracker_head.add_child(_tracker_fold)
	_tracker = RichTextLabel.new()
	_tracker.bbcode_enabled = true
	_tracker.fit_content = true
	_tracker.scroll_active = false
	_tracker.custom_minimum_size = Vector2(TRACKER_WIDTH, 0)
	_tracker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for font in ["normal_font_size", "bold_font_size"]:
		_tracker.add_theme_font_size_override(font, TRACKER_FONT_SIZE)
	tracker_box.add_child(_tracker)

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
	quest_prompt = QuestPrompt.new(self)
	quest_prompt.set_anchors_preset(Control.PRESET_CENTER_TOP)
	quest_prompt.grow_horizontal = Control.GROW_DIRECTION_BOTH
	quest_prompt.position.y += 70
	_root.add_child(quest_prompt)
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

	# The shop sheet over everything else, then the Escape menu (messages, controls,
	# keybinds, leave game) in the middle of the screen over it all.
	_root.move_child(vendor_window, -1)
	game_menu = GameMenu.new(self)
	game_menu.set_anchors_preset(Control.PRESET_CENTER)
	game_menu.grow_horizontal = Control.GROW_DIRECTION_BOTH
	game_menu.grow_vertical = Control.GROW_DIRECTION_BOTH
	_root.add_child(game_menu)


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
	_tracker_panel.visible = _tracker.text != "" and not _tracker_covered()
	var age := Time.get_ticks_msec() / 1000.0 - client.error_at
	_error.text = client.error_text if age < ERROR_SECONDS else ""
	_error.modulate.a = clampf((ERROR_SECONDS - age) / 0.5, 0.0, 1.0)
	_bind_banner.visible = bind_mode


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
	if event.is_action_pressed(&"target_clear") and _escape():
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"toggle_console"):
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
		set_bind_mode(false)
	elif hovered_slot >= 0 and not client.action_bar.set_key(hovered_slot, key):
		client.error("%s is used for something else" % OS.get_keycode_string(key))


## Keybind mode (from the Escape menu): hover an action bar slot, press a key.
func set_bind_mode(on: bool) -> void:
	bind_mode = on


## Esc, WoW-style: the Escape menu closes if open; otherwise open windows close
## (menu book, shop, conversation); otherwise, with nothing targeted, the menu
## opens. Returns false to leave Esc to PlayerInput (cancel aiming, clear target).
func _escape() -> bool:
	if game_menu.visible:
		game_menu.visible = false
		return true
	if input != null and input.is_aiming():
		return false
	var closed := false
	if book.visible:
		close_menus()
		closed = true
	for w in [vendor_window, dialogue]:
		if w.visible:
			w.close()
			closed = true
	if closed:
		return true
	if client.target_id != -1:
		return false
	game_menu.visible = true
	return true


## Dragging the quest tracker by its heading; it stays on screen.
func _on_tracker_drag(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_tracker_dragging = event.pressed
		if event.pressed and _tracker_panel.anchor_left != 0.0:
			# From its place on the right edge to a free position (same spot).
			var at := _tracker_panel.position
			_tracker_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
			_tracker_panel.position = at
		_tracker_panel.accept_event()
	elif event is InputEventMouseMotion and _tracker_dragging:
		var screen := _root.size
		_tracker_panel.position = (_tracker_panel.position + event.relative).clamp(
				Vector2.ZERO, screen - _tracker_panel.size).round()


## Folds the quest tracker down to its heading, or unfolds it.
func _fold_tracker(fold: bool) -> void:
	_tracker.visible = not fold
	_tracker_fold.text = "+" if fold else "–"


func _toggle(panel: Control) -> void:
	panel.visible = not panel.visible
	Audio.play(&"ui_open" if panel.visible else &"ui_close")


## The windows written in the book.
func _book_windows() -> Array[Control]:
	return [_character, inventory_window, loot_window, _spellbook, quest_log, trees_window]


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
		book.page_art = (_open_menu as BookSpread).page_art
		var order := _page_order()
		var at := order.find(_open_menu) # -1 for loot: the arrows lead to the ends
		book.set_turn_labels(_page_name(order[posmod(at - 1, order.size()) if at >= 0 else -1]),
				_page_name(order[posmod(at + 1, order.size()) if at >= 0 else 0]))
		book.fit_pages()


## The menus the book's arrows turn through, in order.
func _page_order() -> Array[Control]:
	return [_character, inventory_window, _spellbook, trees_window, quest_log]


func _page_name(w: Control) -> String:
	return {_character: "Character", inventory_window: "Inventory", _spellbook: "Spellbook",
			trees_window: "Trees", quest_log: "Quests"}.get(w, "")


## The book's arrows: the previous (-1) or next (+1) menu, wrapping around.
func _turn_page(direction: int) -> void:
	var order := _page_order()
	var at := order.find(_open_menu)
	var to: Control = order[posmod(at + direction, order.size())] if at >= 0 \
			else order[0 if direction > 0 else order.size() - 1]
	to.visible = true
	_update_book()


## Closes every menu in the book (its Close button).
func close_menus() -> void:
	for w in _book_windows():
		_close_menu(w)


func _close_menu(w: Control) -> void:
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
			"timing_result":
				if e.source == me:
					timing_bar.show_result(e.grade, e.at, float(e.get("accuracy", -1.0)))
			"game_speed":
				# The host set it in its own rules; a remote client copies it (the host's
				# own copy is the same object).
				session.rules().game_speed = e.value
				game_menu.show_speed(e.value)
				client.say("Game speed: ×%s." % GameMenu.speed_text(e.value))
			"dungeon_testing":
				session.rules().dungeon_testing = e.on
				game_menu.show_dungeon_testing(e.on)
				client.say("Dungeon testing %s." % ("on: any party size may enter" if e.on else "off"))
			"party_wipe":
				client.say("Your party has fallen. Everyone wakes at the entrance…")
			"lift":
				if e.target == me:
					client.say("The lift rattles along its shaft.")
			"joined":
				client.say("%s joined the game." % e.name)
			"left":
				client.say("%s left the game." % e.name)
			"world_flag":
				var announce := ContentDB.dialogue.text("quest.%s.world_flag" % e.get("quest", ""))
				if announce != "":
					client.say(announce)
			"enrage":
				var who = session.get_actor(e.get("source", -1))
				var buff: BuffDef = ContentDB.buffs.get(e.get("buff", &""))
				if who != null and buff != null:
					client.say("%s flies into %s!" % [who.display_name, buff.display_name])
			"zone_reset":
				client.say("The shrine glows: every creature returns to its pen and lingering effects fade.")
			"dialogue":
				# Someone else's conversation: the rest of the party sees a bubble.
				var talker: Actor = session.get_actor(e.npc)
				if talker is Npc and e.get("target", -1) != me:
					client.bubble(talker.id, ContentDB.dialogue.text(
							(talker as Npc).def.greeting_line(session.world_flags(), ContentDB.dialogue), "…"))
			"escort_started", "escort_arrived", "escort_failed":
				_on_escort_event(e)
		if e.get("target", -2) != me:
			continue
		if e.type == "quest_shared":
			var from: Actor = session.get_actor(e.get("source", -1))
			quest_prompt.offer(StringName(e.quest), from.display_name if from != null else "A party member")
			continue
		if e.type == "examined":
			dialogue.open_line("quest.%s.spot.%d.%d" % [e.quest, e.objective, e.spot],
					"You examine the spot closely.", e.tile)
			continue
		var quest_msg := QuestText.event_message(e, ContentDB.quests)
		if quest_msg != "":
			client.say(quest_msg)
			_quest_line_for(e)
			continue
		match e.type:
			"rejected":
				if e.reason == "dungeon_party_too_small":
					client.error(REASONS[e.reason] % int(e.get("need", 3)))
				elif e.reason != "not_ready":
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


## What an NPC says when a quest event happens in your conversation with them:
## accepting, handing in, delivering, using an object.
func _quest_line_for(e: Dictionary) -> void:
	var def: QuestDef = ContentDB.quests.get(StringName(str(e.get("quest", ""))))
	var talking := dialogue.current_npc()
	if def == null or not dialogue.visible or talking == null:
		return
	match e.type:
		"quest_accepted":
			QuestDialogue.show_accepted(self, def)
		"quest_completed":
			dialogue.open(talking) # back to the main page with fresh options
		"delivered":
			dialogue.show_line(def.line_id("deliver.%d" % e.objective), "Thank you. I'll take it from here.")
		"quest_progress":
			var o: QuestObjective = def.objectives[e.objective]
			if o.npc != talking.def.id:
				return
			if o.kind == QuestObjective.Kind.INTERACT and ContentDB.dialogue.has(def.line_id("interact.%d" % e.objective)):
				dialogue.show_line(def.line_id("interact.%d" % e.objective), "", Callable(), DialogueLines.HERO)
			elif o.kind == QuestObjective.Kind.TALK and ContentDB.dialogue.has(def.line_id("talk.%d" % e.objective)):
				# What the person says when the quest sends you to them (their own words).
				dialogue.show_line(def.line_id("talk.%d" % e.objective), "")


## Escorts: the escortee speaks up (its line in your conversation, a bubble for
## everyone), and the log says how it went.
func _on_escort_event(e: Dictionary) -> void:
	var def: QuestDef = ContentDB.quests.get(StringName(str(e.get("quest", ""))))
	var npc: Actor = session.get_actor(e.get("source", -1))
	if def == null or npc == null:
		return
	var i := def.escort_objective()
	match e.type:
		"escort_started":
			var said := ContentDB.dialogue.text(def.line_id("escort.%d" % i), "Let's go. Keep close!")
			client.bubble(npc.id, said)
			client.say("%s sets off. Keep it safe!" % npc.display_name)
			if dialogue.visible and dialogue.npc_id == npc.id:
				dialogue.show_line(def.line_id("escort.%d" % i), said, func(): dialogue.add_option("Goodbye", dialogue.close))
		"escort_arrived":
			client.say("%s made it safely." % npc.display_name)
		"escort_failed":
			client.error("%s was lost!" % npc.display_name)


## Whether an open window overlaps the quest tracker (then the tracker hides,
## so its text never mixes with a menu's).
func _tracker_covered() -> bool:
	if book.visible:
		return true
	var area := _tracker_panel.get_global_rect()
	for w in [dialogue, vendor_window]:
		if w.visible and w.get_global_rect().intersects(area):
			return true
	return false


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
		dialogue.add_option("Browse goods", func():
			vendor_window.open(npc)
			inventory_window.visible = true # your bag, to sell from
			dialogue.visible = false) # out of the way (not closed: the shop stays open)


func _small_button(text: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(on_press)
	return b
