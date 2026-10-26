extends GutTest
## Direction keys always walk (no turn-only taps); the hero faces the mouse.

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


func test_a_tap_walks_even_when_facing_elsewhere() -> void:
	hero.face(Vector2i.UP)
	var start := hero.tile()
	Input.action_press(&"move_right")
	await wait_physics_frames(3)
	Input.action_release(&"move_right")
	await wait_physics_frames(20)
	assert_eq(hero.tile(), start + Vector2i.RIGHT, "walked, no turn-only tap")


func test_keys_never_just_turn_in_combat() -> void:
	_enter_combat()
	hero.face(Vector2i.UP)
	var start := hero.tile()
	Input.action_press(&"move_right")
	await wait_physics_frames(4)
	assert_eq(hero.tile(), start, "the step waits for its cooldown")
	assert_eq(hero.facing, Vector2i.UP, "and the key doesn't turn the hero (the mouse does)")


func test_the_newest_held_key_walks() -> void:
	var start := hero.tile()
	Input.action_press(&"move_up")
	Input.action_press(&"move_left") # pressed last
	await wait_physics_frames(14)
	Input.action_release(&"move_up")
	Input.action_release(&"move_left")
	await wait_physics_frames(10)
	assert_eq(hero.tile().y, start.y, "didn't go up")
	assert_lt(hero.tile().x, start.x, "went left")


func test_hero_faces_the_mouse() -> void:
	var grid: GridModel = session.grid()
	var h := grid.height_at(hero.tile())
	hero.face(Vector2i.UP)
	input.face_toward(Iso.to_screen(Vector2(hero.tile() + Vector2i(3, 1)), h))
	await wait_physics_frames(3)
	assert_eq(hero.facing, Vector2i.RIGHT)
	input.face_toward(Iso.to_screen(Vector2(hero.tile() + Vector2i(-1, 4)), h))
	await wait_physics_frames(3)
	assert_eq(hero.facing, Vector2i.DOWN)
	input.face_toward(Iso.to_screen(Vector2(hero.tile()), h))
	await wait_physics_frames(3)
	assert_eq(hero.facing, Vector2i.DOWN, "pointing at the hero itself changes nothing")


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
