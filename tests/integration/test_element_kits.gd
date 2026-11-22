extends GutTest
## The Hades-style element kits on the buttons (2026-11-22): taps, holds, the Fire
## combo, Water / Ice, the two-press heal, Earth's charged pillar, the weapon on X,
## and the four test characters.

var session: LocalSession
var client: ClientState
var view: WorldView
var input: PlayerInput
var hero: Hero

const X := 0
const Y := 1
const A := 2
const B := 3


func before_each() -> void:
	InputActions.ensure_registered()
	ContentDB.rules.action_combat = true
	session = LocalSession.new()
	add_child(session)
	session.start(ContentDB.zones.values(), &"crossing", ContentDB.rules,
			TestCharacters.make(&"fire", ContentDB))
	hero = session.local_hero()
	client = ClientState.new()
	view = WorldView.new()
	add_child(view)
	view.setup(session, client, ContentDB.zones[&"crossing"])
	input = PlayerInput.new()
	add_child(input)
	input.setup(session, client, view)
	hero.move.place(Vector2i(27, 18))
	input.mouse_override = Iso.to_screen(hero.move.pos + Vector2(3, 0), session.grid().height_at(hero.tile()))
	await wait_physics_frames(2)


func after_each() -> void:
	ContentDB.rules.action_combat = false
	input.free()
	view.free()
	session.free()


func _element(id: StringName) -> void:
	hero.element = id
	for a in ElementKits.all_ability_ids(id):
		hero.mastered[a] = ContentDB.abilities[a]
	client.kit_mode = 0


func _cooling(id: StringName) -> bool:
	return hero.cooldowns.ability_remaining(ContentDB.abilities[id].cooldown_key(), session.now()) > 0.0


func _tap(slot: int) -> void:
	input.press_button(slot)
	input.release_button(slot)
	await wait_physics_frames(3)


## Holds `slot` as if for `seconds` (the hold's start moved back), then lets go.
func _hold(slot: int, seconds: float) -> void:
	input.press_button(slot)
	input._pressed[slot].start -= seconds
	input._update_holds()
	input.release_button(slot)
	await wait_physics_frames(3)


func test_fire_y_tap_is_fire_dart_and_hold_is_fire_whip() -> void:
	await _tap(Y)
	assert_true(_cooling(&"F03"), "a tap: Fire Dart")
	assert_false(_cooling(&"F06"))
	await wait_seconds(0.3)
	await _hold(Y, 1.1)
	assert_true(_cooling(&"F06"), "held 1 s: Fire Whip")


func test_fire_b_is_punch_punch_kick() -> void:
	await _tap(B)
	assert_true(_cooling(&"F01"), "1: Fire Punch")
	await wait_seconds(0.45)
	await _tap(B)
	assert_false(_cooling(&"F02"), "2: Fire Punch again")
	await wait_seconds(0.45)
	await _tap(B)
	assert_true(_cooling(&"F02"), "3: Fire Kick")


func test_the_weapon_is_on_x_tap_and_hold() -> void:
	await _tap(X)
	assert_true(_cooling(&"S01"), "a tap: Slash")
	await wait_seconds(0.3)
	await _hold(X, 3.1)
	assert_true(_cooling(&"S04"), "held 3 s: Lunge")


func test_a_weapon_hold_needs_three_seconds() -> void:
	input.press_button(X)
	input._pressed[X].start -= 1.5
	input._update_holds()
	assert_false(_cooling(&"S04"), "1.5 s isn't enough")
	assert_almost_eq(input.hold_progress(X), 0.5, 0.05, "the ring is half full")


func test_water_switches_to_ice_with_rt() -> void:
	_element(&"water")
	assert_eq(input.mode_name(), "Water")
	assert_true(input.switch_mode())
	assert_eq(input.mode_name(), "Ice")
	await _tap(B)
	assert_true(_cooling(&"W25"), "Ice B: Frost Ring")
	await wait_seconds(0.3)
	await _tap(Y)
	assert_true(_cooling(&"W04"), "Ice Y: Frost Shard")


func test_healing_touch_takes_two_presses_and_the_hero_stands_still() -> void:
	_element(&"water")
	hero.hp -= 40.0
	await _tap(B)
	assert_false(client.ally_select.is_empty(), "first press: choose an ally")
	assert_eq(client.target_id, hero.id, "starting on yourself")
	assert_false(_cooling(&"W01"), "nothing cast yet")
	await _tap(B)
	assert_true(client.ally_select.is_empty())
	assert_true(_cooling(&"W01"), "second press: healed")


func test_earth_pillar_grows_with_the_hold_in_front_of_you() -> void:
	_element(&"earth")
	hero.face(Vector2i.RIGHT)
	var t := hero.tile() + Vector2i(1, 0)
	var ground := session.grid().height_at(t)
	input.press_button(B)
	input._pressed[B].start -= 1.3
	input.release_button(B)
	await wait_physics_frames(3)
	assert_eq(session.grid().height_at(t), ground + 3, "held 1.3 s: three levels")


func test_earth_a_taps_stack_stone_skin() -> void:
	_element(&"earth")
	for i in 3:
		await _tap(A)
		await wait_seconds(0.35)
	assert_eq(hero.buffs.stacks(&"stone_skin", session.now()), 3)


func test_the_test_characters_have_their_whole_kit() -> void:
	for e in TestCharacters.ELEMENTS:
		var d := TestCharacters.make(e, ContentDB)
		assert_eq(d.level, TestCharacters.LEVEL)
		assert_eq(d.element, String(e))
		for id in ElementKits.all_ability_ids(e):
			assert_true(d.mastered.has(String(id)), "%s knows %s" % [e, id])
