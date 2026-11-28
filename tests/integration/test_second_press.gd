extends GutTest
## Pressing an ability's hotkey a second time (2026-11-15, playtest item 5): during
## its timing bar it plays the bar like a right-click or Space, aimed at the cursor
## (briefly removed on 2026-11-21, restored the same day at the user's request);
## while aiming it fires. Another ability's key switches without casting
## either. Held keys (key repeat) never count as a second press.

var session: LocalSession
var client: ClientState
var view: WorldView
var input: PlayerInput
var hero: Hero
var wolf: Enemy

const AREA := Vector2i(22, 10) # open, flat ground east of the Crossing's square


static func _t(x: int, y: int) -> Vector2i:
	return Vector2i(x, y) + AREA


static func _a(x: float, y: float) -> Vector2:
	return Vector2(x, y) + Vector2(AREA)


func before_each() -> void:
	InputActions.ensure_registered()
	ContentDB.rules.timing_bars_enabled = true
	session = LocalSession.new()
	add_child(session)
	session.start(ContentDB.zones.values(), &"crossing", ContentDB.rules,
			CharacterData.new_character("Presser", ContentDB.heroes[&"adventurer"]))
	hero = session.local_hero()
	hero.wear(ContentDB.items[&"rusty_shortsword"]) # heroes start without a weapon
	# Water to bend (the Water Pouch and the Water stance 1 rope, 2026-11-26).
	hero.bag.add(ContentDB.items[Hero.WATER_POUCH])
	hero.water = 200
	hero.stance_water = 24
	client = ClientState.new()
	InputActions.apply_action_bar_keys(client.action_bar)
	view = WorldView.new()
	add_child(view)
	view.setup(session, client, ContentDB.zones[&"crossing"])
	input = PlayerInput.new()
	add_child(input)
	input.setup(session, client, view)
	hero.move.place(_t(5, 8))
	wolf = session.zone_sim().add_enemy(ContentDB.enemies[&"wolf"], _t(6, 8)) # right beside, grid +x
	await wait_physics_frames(2)


func after_each() -> void:
	input.free()
	view.free()
	session.free()


func _point_at(p: Vector2) -> void:
	input.mouse_override = Iso.to_screen(p, session.grid().height_at(MoveState.tile_of(p)))


func _press(id: StringName, key := &"action_slot_1") -> void:
	input.use_slot_ability_for_test(ContentDB.abilities[id], key)


## Waits until `seconds` into the running bar.
func _until(seconds: float) -> void:
	while not hero.casting.is_empty() and session.render_time() - float(hero.casting.start) < seconds:
		await wait_physics_frames(1)


func _first_zone() -> Vector2:
	return hero.casting.ability.timing_bar.inputs()[0].zone # start, length


## A Space press or release, as Godot would deliver it.
func _space(pressed: bool) -> void:
	var ev := InputEventAction.new()
	ev.action = &"timing_press"
	ev.pressed = pressed
	if pressed:
		input._unhandled_input(ev)
	else:
		input._input(ev)


func test_a_second_press_of_slash_plays_its_bar_aimed_at_the_cursor() -> void:
	_point_at(_a(5, 11)) # away from the wolf when the bar starts
	_press(&"S01")
	await wait_physics_frames(4)
	assert_eq(hero.casting.get("kind", ""), "timing", "the first press starts the bar")
	if hero.casting.is_empty():
		return
	var hp := wolf.hp
	_point_at(_a(6, 8)) # onto the wolf
	var z := _first_zone()
	await _until(z.x + z.y / 2.0)
	_press(&"S01") # the second press: like a right-click, in the green zone
	await wait_physics_frames(3)
	assert_true(hero.casting.is_empty(), "the swing went off")
	assert_gt(hero.cooldowns.ability_remaining(&"S01", session.now()), 0.0)
	assert_lt(wolf.hp, hp, "toward the cursor at the second press")


func test_space_plays_slash_s_bar() -> void:
	_point_at(_a(5, 11)) # away from the wolf when the bar starts
	_press(&"S01")
	await wait_physics_frames(4)
	assert_eq(hero.casting.get("kind", ""), "timing", "the first press starts the bar")
	if hero.casting.is_empty():
		return
	var hp := wolf.hp
	_point_at(_a(6, 8)) # onto the wolf
	var z := _first_zone()
	await _until(z.x + z.y / 2.0)
	_space(true) # Space: like a right-click, in the green zone
	_space(false)
	await wait_physics_frames(3)
	assert_true(hero.casting.is_empty(), "the swing went off")
	assert_gt(hero.cooldowns.ability_remaining(&"S01", session.now()), 0.0)
	assert_lt(wolf.hp, hp, "toward the cursor at the Space press")


func test_letting_go_of_the_key_ends_a_hold() -> void:
	# Water Whip: one blue hold zone. Second press = start the hold; let go of the
	# key at the zone's end = a well-held bar.
	hero.bag.add(ContentDB.items[&"river_lash_scroll"])
	TreeRules.learn_from_bag(hero, hero.bag.index_of(ContentDB.items[&"river_lash_scroll"]))
	client.target_id = wolf.id
	_press(&"W02", &"action_slot_2")
	await wait_physics_frames(4)
	assert_eq(hero.casting.get("kind", ""), "timing")
	if hero.casting.is_empty():
		return
	var z := _first_zone()
	await _until(z.x + 0.02)
	_press(&"W02", &"action_slot_2")
	await wait_physics_frames(2)
	assert_true(hero.casting.has("hold_from"), "the second press started the hold")
	await _until(z.x + z.y - 0.03)
	var release := InputEventAction.new()
	release.action = &"action_slot_2"
	release.pressed = false
	input._input(release)
	await wait_physics_frames(3)
	assert_true(hero.casting.is_empty(), "letting go of the key ended the hold and released the lash")
	await wait_seconds(ContentDB.abilities[&"W02"].release_delay_seconds + 0.15)
	assert_gt(hero.cooldowns.ability_remaining(&"W02", session.now()), 0.0)


func test_letting_go_of_space_ends_a_hold() -> void:
	# Water Whip: one blue hold zone. Space = start the hold; let go of Space at the
	# zone's end = a well-held bar.
	hero.bag.add(ContentDB.items[&"river_lash_scroll"])
	TreeRules.learn_from_bag(hero, hero.bag.index_of(ContentDB.items[&"river_lash_scroll"]))
	client.target_id = wolf.id
	_press(&"W02", &"action_slot_2")
	await wait_physics_frames(4)
	assert_eq(hero.casting.get("kind", ""), "timing")
	if hero.casting.is_empty():
		return
	var z := _first_zone()
	await _until(z.x + 0.02)
	_space(true)
	await wait_physics_frames(2)
	assert_true(hero.casting.has("hold_from"), "Space started the hold")
	await _until(z.x + z.y - 0.03)
	_space(false)
	await wait_physics_frames(3)
	assert_true(hero.casting.is_empty(), "letting go of Space ended the hold and released the lash")
	# It goes off on the lash's snap (AbilityDef.release_delay_seconds, since 2026-11-21).
	await wait_seconds(ContentDB.abilities[&"W02"].release_delay_seconds + 0.15)
	assert_gt(hero.cooldowns.ability_remaining(&"W02", session.now()), 0.0)


func test_another_abilitys_key_switches_without_casting_either() -> void:
	client.target_id = wolf.id
	var mana := hero.mana
	_press(&"S01")
	await wait_physics_frames(4)
	assert_eq(hero.casting.get("ability", null), ContentDB.abilities[&"S01"], "Slash's bar runs")
	hero.bag.add(ContentDB.items[&"river_lash_scroll"]) # Fire Punch is instant since 2026-11-21
	TreeRules.learn_from_bag(hero, hero.bag.index_of(ContentDB.items[&"river_lash_scroll"]))
	_press(&"W02", &"action_slot_2") # Water Whip's key
	await wait_physics_frames(4)
	assert_eq(hero.casting.get("ability", null), ContentDB.abilities[&"W02"],
			"switched to Water Whip's bar (the global cooldown Slash took was given back)")
	assert_eq(hero.cooldowns.ability_remaining(&"S01", session.now()), 0.0, "Slash didn't go off")
	assert_eq(hero.cooldowns.ability_remaining(&"W02", session.now()), 0.0, "nor Water Whip, yet")
	assert_eq(hero.mana, mana, "nothing paid")


func test_a_second_press_fires_an_aimed_ability_without_a_bar() -> void:
	# Lunge has no bar: clicked on the action bar it aims; its key then fires it.
	hero.bag.add(ContentDB.items[&"travelers_longsword"])
	Mastery.add_permanent(hero, "Sword", 50) # Lunge unlocks a step in (stance rework)
	hero.equip_from_bag(hero.bag.index_of(ContentDB.items[&"travelers_longsword"]))
	wolf.move.place(_t(9, 4))
	_point_at(_a(5, 5)) # north
	var start := hero.move.pos
	_press(&"S04", &"") # a click on the bar: aiming
	assert_true(input.is_aiming())
	_press(&"S04", &"action_slot_3") # then its key
	assert_false(input.is_aiming(), "fired")
	await wait_physics_frames(15)
	assert_almost_eq(rad_to_deg((hero.move.pos - start).angle()), -90.0, 10.0, "toward the cursor")


func test_a_held_key_is_not_a_second_press() -> void:
	# Key repeat sends echo events; they must not play the bar.
	var ev := InputEventKey.new()
	ev.physical_keycode = client.action_bar.keys[0]
	ev.pressed = true
	client.action_bar.slots[0] = &"S01"
	input._unhandled_input(ev)
	await wait_physics_frames(4)
	assert_eq(hero.casting.get("kind", ""), "timing", "the press started the bar")
	if hero.casting.is_empty():
		return
	var z := _first_zone()
	await _until(z.x + z.y / 2.0)
	var echo := ev.duplicate()
	echo.echo = true
	input._unhandled_input(echo)
	await wait_physics_frames(3)
	assert_eq(hero.casting.get("kind", ""), "timing", "the held key's repeats didn't play the bar")
