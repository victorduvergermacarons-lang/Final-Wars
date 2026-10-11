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

	# Saving writes the hero's progress to the store.
	game.store = CharacterStore.new("user://test_smoke_characters")
	game.save_now()
	assert_eq(game.store.load_character("Tester").equipped["5"], "staff")
	game.store.delete("Tester")

	game.free()
	await wait_process_frames(1)
