extends GutTest
## Direction keys in combat: turning must be immediate, even while the next
## step is on cooldown or another direction key is still held.

var session: LocalSession
var input: PlayerInput
var hero: Hero


func before_each() -> void:
	InputActions.ensure_registered()
	session = LocalSession.new()
	add_child(session)
	session.start(ContentDB.zones.values(), &"town", ContentDB.rules,
			CharacterData.new_character("Turner", ContentDB.heroes[&"adventurer"]))
	hero = session.local_hero()
	input = PlayerInput.new()
	add_child(input)
	input.setup(session, ClientState.new(), null)


func after_each() -> void:
	for action in InputActions.DIRECTIONS:
		Input.action_release(action)
	input.free()
	session.free()


func _enter_combat() -> void:
	hero.combat_until = 1.0e9
	hero.cooldowns.trigger_step(session.now(), 30.0) # next step far away


func test_tap_turns_immediately_in_combat() -> void:
	_enter_combat()
	hero.face(Vector2i.UP)
	var start := hero.tile()
	Input.action_press(&"move_right")
	await wait_physics_frames(4)
	assert_eq(hero.facing, Vector2i.RIGHT)
	assert_eq(hero.tile(), start, "turned without moving")


func test_rolling_to_a_second_key_turns_while_the_first_is_held() -> void:
	_enter_combat()
	hero.face(Vector2i.UP)
	Input.action_press(&"move_up")
	await wait_physics_frames(4)
	Input.action_press(&"move_left") # still holding W
	await wait_physics_frames(4)
	assert_eq(hero.facing, Vector2i.LEFT, "the newest key wins")
	Input.action_release(&"move_left")
	await wait_physics_frames(4)
	assert_eq(hero.facing, Vector2i.UP, "back to the key still held")


func test_turning_cancels_a_queued_step() -> void:
	var sim := session.zone_sim()
	hero.pending_step = hero.tile() + Vector2i.UP
	sim.submit(hero.id, {"type": "face", "dir": Vector2i.RIGHT})
	sim.step()
	assert_null(hero.pending_step, "the old queued step is dropped")
	assert_eq(hero.facing, Vector2i.RIGHT)


func test_shift_number_switches_the_action_bar_page() -> void:
	var client: ClientState = input.client
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_3
	ev.shift_pressed = true
	ev.pressed = true
	Input.parse_input_event(ev)
	await wait_process_frames(2)
	assert_eq(client.action_bar.page, 2, "Shift+3 shows bar 3")
	var plain := InputEventKey.new()
	plain.physical_keycode = KEY_3
	plain.pressed = true
	Input.parse_input_event(plain)
	await wait_process_frames(2)
	assert_eq(client.action_bar.page, 2, "plain 3 is a slot key, not a page switch")
