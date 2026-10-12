extends GutTest
## Runs the real solo game scene headless and drives it through the HUD and
## input layers, to catch errors there and check the pieces are wired up.

const SETTINGS := "user://test_settings.cfg"


func before_each() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS))


func after_all() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS))


func test_solo_game_runs_with_hud() -> void:
	var game := Game.new()
	game.settings_path = SETTINGS
	add_child(game)
	game.start_solo(CharacterData.new_character("Tester", ContentDB.heroes[&"adventurer"]))
	var session: LocalSession = game.session
	var hero := session.local_hero()
	var input: PlayerInput = game.get_node("PlayerInput")
	var hud: Hud = game.get_node("Hud")

	# Movement intent.
	var start := hero.tile()
	session.send_intent({"type": "step", "to": start + Vector2i.UP})
	await wait_physics_frames(30)
	assert_ne(hero.tile(), start, "hero moved")

	# Starting abilities were auto-placed on the bar in order.
	assert_eq(game.client.action_bar.slots.slice(0, 3), [&"strike", &"heal", &"resurrect"] as Array[StringName])

	# Slot 2 (Heal) casts on self with no target; the GCD starts.
	hero.hp -= 30
	input.use_slot(1)
	await wait_physics_frames(6)
	assert_gt(hero.cooldowns.gcd_remaining(session.now()), 0.0, "heal went through the action bar")

	# Strike needs no target: it hits the tile in front (here: nobody, so it whiffs).
	var whiffs := []
	session.events_received.connect(func(events):
		for e in events:
			if e.type == "whiff":
				whiffs.append(e))
	await wait_physics_frames(70) # let the 1 s GCD from Heal run out (60 physics frames per second)
	input.use_slot(0)
	await wait_physics_frames(6)
	assert_eq(whiffs.size(), 1, "Strike went out and hit nothing")

	# Equip the Staff from the inventory window (out of combat): Fireball appears on the bar.
	hud._toggle(hud.inventory_window)
	hud._toggle(hud._character)
	hud._toggle(hud._spellbook)
	hud._toggle(hud.quest_log)
	await wait_process_frames(2)
	var staff_index := hero.bag.index_of(ContentDB.items[&"staff"])
	assert_gt(staff_index, -1)
	var main_hand: ItemSlotView = null
	for v in hud.inventory_window.find_children("*", "ItemSlotView", true, false):
		if v.kind == ItemSlotView.Kind.EQUIP and v.index == EquipSlot.Id.MAIN_HAND:
			main_hand = v
	main_hand._drop_data(Vector2.ZERO, {"item_from": ItemSlotView.Kind.BAG, "index": staff_index})
	await wait_physics_frames(6)
	await wait_process_frames(2)
	assert_eq(hero.equipped_in(EquipSlot.Id.MAIN_HAND).id, &"staff")
	assert_eq(hero.bag.count_of(ContentDB.items[&"sword"]), 1, "the sword went to the bag")
	assert_true(game.client.action_bar.slots.has(&"fireball"))
	assert_true(game.client.action_bar.slots.has(&"strike"), "Strike's slot stays (dimmed)")
	var tooltip = main_hand._make_custom_tooltip("")
	assert_not_null(tooltip, "tooltip builds")
	tooltip.free()

	# The layout was saved to the settings file.
	var reloaded := ActionBarModel.new()
	SettingsStore.load_action_bar(reloaded, SETTINGS)
	assert_eq(reloaded.slots, game.client.action_bar.slots)

	# Talking to Hilda opens the dialogue box; walking away closes it.
	hero.move.place(Vector2i(7, 7))
	hero.face(Vector2i.UP)
	input.talk_to_nearest()
	await wait_physics_frames(6)
	await wait_process_frames(1)
	assert_true(hud.dialogue.visible, "dialogue opened")
	assert_eq(hud.dialogue.current_npc().def.id, &"hilda")
	# Buy a potion from Hilda, put it on the action bar and drink it.
	hero.gold = 100
	hud.vendor_window.open(hud.dialogue.current_npc())
	hud.vendor_window.buy_item(&"minor_health_potion")
	await wait_physics_frames(6)
	var potion: ItemDef = ContentDB.items[&"minor_health_potion"]
	assert_eq(hero.bag.count_of(potion), 1, "bought")
	assert_eq(hero.gold, 80)
	var slot: SlotButton = hud.find_children("*", "SlotButton", true, false)[6]
	slot._drop_data(Vector2.ZERO, {"item_from": ItemSlotView.Kind.BAG, "index": hero.bag.index_of(potion)})
	assert_eq(game.client.action_bar.slots[6], &"item:minor_health_potion")
	hero.hp = 10
	input.use_slot(6)
	await wait_physics_frames(6)
	assert_gt(hero.hp, 50.0, "drank it")
	assert_eq(hero.bag.count_of(potion), 0)

	hero.move.place(Vector2i(14, 16))
	await wait_process_frames(2)
	assert_false(hud.dialogue.visible, "closed after walking away")
	assert_false(hud.vendor_window.visible, "shop closes with the conversation")

	# Captain Rowan offers a quest ("!"); accept it through the dialogue buttons.
	await wait_process_frames(1)
	assert_eq(game.client.npc_markers.get(&"rowan"), "!", "Rowan has a quest")
	hero.move.place(Vector2i(11, 9))
	input.talk_to_nearest()
	await wait_physics_frames(6)
	await wait_process_frames(1)
	assert_eq(hud.dialogue.current_npc().def.id, &"rowan")
	var offer := _option(hud, "! Wolves at the Gate")
	assert_not_null(offer, "quest offered in the dialogue")
	offer.pressed.emit()
	await wait_process_frames(1)
	_option(hud, "Accept").pressed.emit()
	await wait_physics_frames(6)
	await wait_process_frames(2)
	assert_true(QuestLog.is_active(hero, &"wolves_at_the_gate"))
	assert_string_contains(hud._tracker.text, "Wolves at the Gate", "tracked on screen")
	assert_eq(game.client.npc_markers.get(&"rowan", ""), "", "no more to offer until it's done")
	hero.move.place(Vector2i(14, 16))
	await wait_process_frames(2)

	# Leaving town through the east exit switches the map.
	var old_view := game.get_node("WorldView")
	hero.move.place(Vector2i(16, 9))
	session.send_intent({"type": "step", "to": Vector2i(17, 9)})
	await wait_physics_frames(30)
	assert_eq(session.zone().id, &"greenfields")
	var new_view := game.get_node_or_null("WorldView")
	assert_not_null(new_view)
	assert_ne(new_view, old_view, "the view was rebuilt for the new zone")
	assert_eq(session.actors().filter(func(a): return a is Enemy).size(), 11, "now seeing Greenfields' enemies")

	# Saving writes the hero's progress to the store.
	game.store = CharacterStore.new("user://test_smoke_characters")
	game.save_now()
	assert_eq(game.store.load_character("Tester").equipped["5"], "staff")
	game.store.delete("Tester")

	game.free()
	await wait_process_frames(1)


func _option(hud: Hud, text: String) -> Button:
	for b in hud.dialogue.find_children("*", "Button", true, false):
		if b.text == text and not b.is_queued_for_deletion():
			return b
	return null
