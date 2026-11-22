extends GutTest
## Free movement keys: WASD give 8 screen-relative directions (W = up the
## screen), diagonals no faster; the hero faces the mouse in combat and the way it
## walks otherwise.

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
	hero.move.place(Vector2i(6, 7)) # open ground (the spawn point is beside the Village Well)
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


func _held_for(actions: Array, frames: int) -> void:
	for action in actions:
		Input.action_press(action)
	await wait_physics_frames(frames)
	for action in actions:
		Input.action_release(action)


func test_w_walks_up_the_screen() -> void:
	var start := hero.move.pos
	await _held_for([&"move_up"], 12)
	var d := hero.move.pos - start
	assert_gt(d.length(), 0.3, "walked")
	assert_almost_eq(d.normalized().angle(), Mover.screen_to_grid(Vector2i(0, -1)).angle(), 0.1,
			"up the screen (grid up-left)")


func test_two_keys_make_a_diagonal_no_faster_than_one() -> void:
	var start := hero.move.pos
	await _held_for([&"move_up", &"move_right"], 12)
	var d := hero.move.pos - start
	assert_almost_eq(d.normalized().angle(), Mover.screen_to_grid(Vector2i(1, -1)).angle(), 0.1, "up-right on screen")
	await wait_physics_frames(10)
	hero.move.place(start)
	await wait_physics_frames(4)
	await _held_for([&"move_up"], 12)
	var single := hero.move.pos - start
	assert_almost_eq(d.length(), single.length(), 0.2, "the diagonal isn't faster")


func test_opposite_keys_cancel_and_release_stops() -> void:
	var start := hero.move.pos
	await _held_for([&"move_left", &"move_right"], 10)
	assert_lt(hero.move.pos.distance_to(start), 0.05, "left + right: no movement")
	await _held_for([&"move_down"], 10)
	await wait_physics_frames(6)
	assert_eq(hero.move.vel, Vector2.ZERO, "stops once the key is let go")


func test_in_combat_the_hero_faces_the_mouse() -> void:
	_enter_combat()
	var grid: GridModel = session.grid()
	var h := grid.height_at(hero.tile())
	input.face_toward(Iso.to_screen(hero.move.pos + Vector2(3, 0), h))
	await wait_physics_frames(3)
	assert_almost_eq(hero.facing_angle, 0.0, 0.05, "toward the mouse")
	assert_eq(hero.facing, Vector2i.RIGHT, "sprite: nearest diagonal")
	input.face_toward(Iso.to_screen(hero.move.pos + Vector2(0, 4), h))
	await wait_physics_frames(3)
	assert_almost_eq(hero.facing_angle, PI / 2.0, 0.05)
	assert_eq(hero.facing, Vector2i.DOWN)


func test_out_of_combat_the_hero_faces_where_it_walks() -> void:
	await _held_for([&"move_down"], 10)
	assert_almost_eq(hero.facing_angle, Mover.screen_to_grid(Vector2i(0, 1)).angle(), 0.1)


func test_the_stick_walks_any_angle_as_fast_as_it_is_pushed() -> void:
	# A controller's left stick: straight up the screen (between grid up and grid
	# left), full push; then the same at half push.
	var start := hero.move.pos
	for i in 12:
		session.send_intent({"type": "move", "dir": Vector2i.ZERO, "face": 0.0, "stick": Vector2(0, -1)})
		await wait_physics_frames(1)
	var full := hero.move.pos - start
	assert_almost_eq(full.normalized().angle(), Mover.stick_to_grid(Vector2(0, -1)).angle(), 0.1, "up the screen")
	session.send_intent({"type": "move", "dir": Vector2i.ZERO, "face": 0.0})
	await wait_physics_frames(10)
	hero.move.place(start)
	await wait_physics_frames(2)
	for i in 12:
		session.send_intent({"type": "move", "dir": Vector2i.ZERO, "face": 0.0, "stick": Vector2(0, -0.5)})
		await wait_physics_frames(1)
	var half := hero.move.pos - start
	assert_almost_eq(half.length(), full.length() * 0.5, full.length() * 0.15, "half push, half speed")


func test_the_last_device_touched_is_the_one_in_use() -> void:
	InputDevice.set_kind(InputDevice.Kind.KEYBOARD)
	var b := InputEventJoypadButton.new()
	b.button_index = JOY_BUTTON_A
	b.pressed = true
	assert_true(InputDevice.note(b))
	assert_true(InputDevice.using_pad())
	assert_eq(InputActions.hint(&"action_slot_1"), "X", "slot 1 on the left face button")
	var nudge := InputEventMouseMotion.new()
	nudge.relative = Vector2(2, 0)
	assert_false(InputDevice.note(nudge), "a tiny mouse nudge doesn't switch")
	var k := InputEventKey.new()
	k.physical_keycode = KEY_Q
	k.pressed = true
	assert_true(InputDevice.note(k))
	assert_eq(InputActions.hint(&"action_slot_1"), "Left click")
	assert_eq(InputActions.hint(&"timing_press", InputDevice.Kind.GAMEPAD), "RT")
