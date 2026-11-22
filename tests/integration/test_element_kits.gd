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
	await _hold(X, 2.1)
	assert_true(_cooling(&"S04"), "held 2 s: Lunge")


func test_a_weapon_hold_needs_two_seconds() -> void:
	input.press_button(X)
	input._pressed[X].start -= 1.0
	input._update_holds()
	assert_false(_cooling(&"S04"), "1 s isn't enough")
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


func test_a_dash_goes_the_way_you_walk_not_where_you_aim() -> void:
	# The cursor is to the grid right (before_each); walking grid down (S+A).
	input._held = Vector2i(-1, 1)
	var p := input.point_for(ContentDB.abilities[&"F05"])
	var dir := (p - hero.move.pos).normalized()
	assert_almost_eq(dir.angle(), Mover.screen_to_grid(Vector2i(-1, 1)).angle(), 0.05, "Flame Dash along the walk")
	input._held = Vector2i.ZERO
	var fireball := input.point_for(ContentDB.abilities[&"F03"])
	assert_gt(fireball.x - hero.move.pos.x, 1.0, "an attack still goes where you aim")

func test_a_hold_let_go_early_goes_off_smaller() -> void:
	input.press_button(Y)
	input._pressed[Y].start -= 0.6
	input._update_holds()
	assert_true(client.aim.get("hold", false), "holding shows the growing area")
	assert_eq(client.aim.get("color"), PlayerInput.HOLD_AIM_COLOR, "in red")
	var part: float = (client.aim.ability as AbilityDef).hitbox.reach
	assert_lt(part, ContentDB.abilities[&"F06"].hitbox.reach, "not full size yet")
	input.release_button(Y)
	await wait_physics_frames(3)
	assert_true(client.aim.is_empty(), "the area goes when you let go")
	assert_true(_cooling(&"F06"), "let go early: Fire Whip all the same")
	assert_false(_cooling(&"F03"), "not the tap")


func test_the_area_grows_with_the_hold() -> void:
	input.press_button(Y)
	input._pressed[Y].start -= 0.4
	input._update_holds()
	var small: float = (client.aim.ability as AbilityDef).hitbox.reach
	input._pressed[Y].start -= 0.4
	input._update_holds()
	var big: float = (client.aim.ability as AbilityDef).hitbox.reach
	assert_gt(big, small)


func _dash_distance(seconds: float) -> float:
	hero.move.place(Vector2i(27, 18))
	hero.face(Vector2i.RIGHT)
	hero.cooldowns = Cooldowns.new()
	var from := hero.move.pos
	input.press_button(A)
	input._pressed[A].start -= seconds
	input._update_holds()
	input.release_button(A)
	await wait_physics_frames(3)
	return (hero.move.to_point if hero.move.gliding else hero.move.pos).distance_to(from)


func test_flame_dash_goes_two_tiles_on_a_tap_and_up_to_six_held() -> void:
	var tap := await _dash_distance(0.0)
	assert_almost_eq(tap, 2.0, 0.3, "a tap: 2 tiles")
	await wait_seconds(0.3)
	var held := await _dash_distance(1.1)
	assert_gt(held, tap + 1.5, "held: further (up to 6)")


func test_punches_and_the_kick_step_forward() -> void:
	var from := hero.move.pos
	await _tap(B)
	var punch := hero.move.to_point.distance_to(from) if hero.move.gliding else hero.move.pos.distance_to(from)
	assert_almost_eq(punch, 0.35, 0.06, "a punch steps a little")
	await wait_seconds(0.45)
	await _tap(B)
	await wait_seconds(0.45)
	from = hero.move.pos
	await _tap(B)
	var kick := hero.move.to_point.distance_to(from) if hero.move.gliding else hero.move.pos.distance_to(from)
	assert_gt(kick, punch + 0.2, "the kick steps further")
