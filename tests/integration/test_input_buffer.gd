extends GutTest
## Input buffering (2026-11-28, user: ".3s"): an ability pressed up to 0.3 s before it
## could go (its cooldown, the global cooldown or a cast still running) waits and goes
## off by itself the moment it can. Pressed earlier, it is refused as before.

var session: LocalSession
var client: ClientState
var view: WorldView
var input: PlayerInput
var hero: Hero
var wolf: Enemy

const AREA := Vector2i(22, 10)


func before_each() -> void:
	InputActions.ensure_registered()
	ContentDB.rules.timing_bars_enabled = false # Slash swings at once
	session = LocalSession.new()
	add_child(session)
	session.start(ContentDB.zones.values(), &"crossing", ContentDB.rules,
			CharacterData.new_character("Buffer", ContentDB.heroes[&"adventurer"]))
	hero = session.local_hero()
	hero.wear(ContentDB.items[&"rusty_shortsword"])
	client = ClientState.new()
	InputActions.apply_action_bar_keys(client.action_bar)
	view = WorldView.new()
	add_child(view)
	view.setup(session, client, ContentDB.zones[&"crossing"])
	input = PlayerInput.new()
	add_child(input)
	input.setup(session, client, view)
	hero.move.place(Vector2i(5, 8) + AREA)
	wolf = session.zone_sim().add_enemy(ContentDB.enemies[&"wolf"], Vector2i(6, 8) + AREA)
	input.mouse_override = Iso.to_screen(Vector2(wolf.move.pos), session.grid().height_at(wolf.tile()))
	await wait_physics_frames(2)


func after_each() -> void:
	ContentDB.rules.timing_bars_enabled = true
	input.free()
	view.free()
	session.free()


func _slash_left() -> float:
	return hero.cooldowns.ability_remaining(&"S01", session.now())


func _until_left(seconds: float) -> void:
	while _slash_left() > seconds:
		await wait_physics_frames(1)


func test_a_press_just_before_the_cooldown_ends_goes_off_when_it_ends() -> void:
	var slash: AbilityDef = ContentDB.abilities[&"S01"]
	input.use_slot_ability_for_test(slash, &"action_slot_1")
	await wait_physics_frames(3)
	assert_gt(_slash_left(), 1.0, "Slash went off")
	await _until_left(0.2)
	input.use_slot_ability_for_test(slash, &"action_slot_1") # 0.2 s early
	assert_gt(input.ready_in(hero, slash), 0.0, "not ready yet: kept")
	await _until_left(0.0)
	await wait_physics_frames(4)
	assert_gt(_slash_left(), slash.cooldown_seconds - 0.4, "it went off on its own when ready")


func test_a_press_long_before_is_not_kept() -> void:
	var slash: AbilityDef = ContentDB.abilities[&"S01"]
	input.use_slot_ability_for_test(slash, &"action_slot_1")
	await wait_physics_frames(3)
	await _until_left(1.0)
	input.use_slot_ability_for_test(slash, &"action_slot_1") # a second early
	await _until_left(0.0)
	await wait_physics_frames(10)
	assert_eq(_slash_left(), 0.0, "nothing went off by itself")
