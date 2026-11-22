extends GutTest
## Aiming (Milestone 3 §3): hold an aimed ability's key, see the exact tiles it
## would affect, release to cast. Telegraphs and previews on the client copy.

var session: LocalSession
var client: ClientState
var view: WorldView
var input: PlayerInput
var hero: Hero
var wolf: Enemy

## The test plays on open, flat ground east of the Crossing's square; tiles are
## given relative to it.
const AREA := Vector2i(22, 10)


static func _t(x: int, y: int) -> Vector2i:
	return Vector2i(x, y) + AREA


static func _a(x: float, y: float) -> Vector2:
	return Vector2(x, y) + Vector2(AREA)


func before_each() -> void:
	InputActions.ensure_registered()
	ContentDB.rules.timing_bars_enabled = false # aiming, not bars (test_timing_bar.gd)
	session = LocalSession.new()
	add_child(session)
	session.start(ContentDB.zones.values(), &"crossing", ContentDB.rules,
			CharacterData.new_character("Aimer", ContentDB.heroes[&"adventurer"]))
	hero = session.local_hero()
	hero.wear(ContentDB.items[&"rusty_shortsword"]) # heroes start without a weapon
	client = ClientState.new()
	view = WorldView.new()
	add_child(view)
	view.setup(session, client, ContentDB.zones[&"crossing"])
	input = PlayerInput.new()
	add_child(input)
	input.setup(session, client, view)
	hero.move.place(_t(5, 8))
	hero.face(Vector2i.RIGHT)
	wolf = session.zone_sim().add_enemy(ContentDB.enemies[&"wolf"], _t(8, 8))
	hero.bag.add(ContentDB.items[&"spark_scroll"])
	TreeRules.learn_from_bag(hero, hero.bag.index_of(ContentDB.items[&"spark_scroll"]))


func after_each() -> void:
	ContentDB.rules.timing_bars_enabled = true
	input.free()
	view.free()
	session.free()


func _preview(id: StringName, aim: Vector2) -> Array:
	var p := AimPreview.preview(session.grid(), session.rules(), session.actors(), hero, ContentDB.abilities[id],
			aim, null, session.now())
	return p.tiles


func test_screen_to_tile_round_trip() -> void:
	for h in [0, 1, 3]:
		var t := _a(7, 4)
		var back := Iso.from_screen(Iso.to_screen(t, h), h)
		assert_almost_eq(back.x, t.x, 0.001)
		assert_almost_eq(back.y, t.y, 0.001)
	var tile := _t(6, 9)
	var screen := Iso.to_screen(Vector2(tile), session.grid().height_at(tile))
	assert_eq(view.tile_at(screen), tile, "the tile under the cursor")


func test_aimed_abilities_need_no_target() -> void:
	var dart: AbilityDef = ContentDB.abilities[&"F03"]
	assert_true(AimPreview.is_aimed(dart))
	assert_eq(Targeting.pick(hero, dart, null).error, "")
	assert_eq(Targeting.pick(hero, ContentDB.abilities[&"F04"], null).target, hero.id, "self abilities")


func _outline(id: StringName, aim: Vector2) -> PackedVector2Array:
	return AimPreview.preview(session.grid(), session.rules(), session.actors(), hero, ContentDB.abilities[id],
			aim, null, session.now()).outline


func _inside(poly: PackedVector2Array, p: Vector2) -> bool:
	return Geometry2D.is_point_in_polygon(p, poly)


func test_previews_show_the_exact_shape() -> void:
	var dart := _outline(&"F03", _a(12, 8))
	assert_true(_inside(dart, _a(8, 8)), "the dart's lane toward the aim")
	assert_false(_inside(dart, _a(5, 10)), "nothing beside it")
	var whip := _outline(&"F06", _a(9, 12))
	assert_true(_inside(whip, _a(5, 8).lerp(_a(9, 12), 0.4)), "the whip follows the mouse at any angle")
	var blast := _outline(&"F07", _a(8, 8))
	assert_true(_inside(blast, _a(8, 8)) and _inside(blast, _a(9, 8)), "a circle at the aim")
	assert_false(_inside(blast, _a(10, 8)))
	var wall := _preview(&"E05", _a(5, 11))
	assert_eq(wall, [_t(4, 11), _t(5, 11), _t(6, 11)], "a wall across the aim, still on tiles")
	assert_eq(hero.facing, Vector2i.RIGHT, "previewing doesn't turn the hero")
	var dash := _outline(&"F05", _a(5, 11))
	assert_true(_inside(dash, _a(5, 10)), "the dash path")
	assert_false(_inside(dash, _a(5, 12)), "only as far as it dashes")


## Puts the (test) cursor over a point of the map.
func _point_at(p: Vector2) -> void:
	input.mouse_override = Iso.to_screen(p, session.grid().height_at(MoveState.tile_of(p)))


func test_hold_to_aim_and_release_to_cast() -> void:
	client.target_id = wolf.id
	_point_at(_a(5, 11))
	input.use_slot_ability_for_test(ContentDB.abilities[&"F03"], &"action_slot_1")
	assert_true(input.is_aiming())
	assert_false(client.aim.is_empty())
	assert_almost_eq(client.aim.point, _a(5, 11), Vector2(0.01, 0.01),
			"aims at the cursor, not at the targeted wolf")
	assert_true(client.aim.valid)
	var release := InputEventAction.new()
	release.action = &"action_slot_1"
	release.pressed = false
	input._unhandled_input(release)
	assert_false(input.is_aiming())
	assert_true(client.aim.is_empty())
	await wait_physics_frames(3)
	assert_gt(hero.cooldowns.ability_remaining(&"F03", session.now()), 0.0, "the dart was cast")


func test_escape_cancels_aiming() -> void:
	input.use_slot_ability_for_test(ContentDB.abilities[&"F03"], &"action_slot_1")
	var esc := InputEventAction.new()
	esc.action = &"target_clear"
	esc.pressed = true
	input._unhandled_input(esc)
	assert_false(input.is_aiming())
	await wait_physics_frames(3)
	assert_eq(hero.cooldowns.ability_remaining(&"F03", session.now()), 0.0, "nothing cast")


func test_out_of_range_aims_are_pulled_back_or_refused() -> void:
	hero.bag.add(ContentDB.items[&"scroll_of_the_fireball"])
	TreeRules.master(hero, ContentDB.abilities[&"F07"])
	var p := AimPreview.preview(session.grid(), session.rules(), session.actors(), hero, ContentDB.abilities[&"F07"],
			_a(16, 8), null, session.now())
	assert_eq(p.result, AbilityResolver.Result.OK, "a circle aimed too far lands at the edge of its range")
	assert_true(_inside(p.outline, _a(12, 8)), "7 tiles out (5 until the 2026-11-17 rebalance)")
	assert_false(_inside(p.outline, _a(16, 8)))
	# A grid ability (terrain) still refuses an aim out of range.
	TreeRules.master(hero, ContentDB.abilities[&"E03"])
	p = AimPreview.preview(session.grid(), session.rules(), session.actors(), hero, ContentDB.abilities[&"E03"],
			_a(16, 8), null, session.now())
	assert_eq(p.result, AbilityResolver.Result.OUT_OF_RANGE)


func test_telegraphs_and_zones_reach_the_view() -> void:
	var sim := session.zone_sim()
	TreeRules.master(hero, ContentDB.abilities[&"F08"])
	sim.cast(hero, ContentDB.abilities[&"F08"], null, _a(8, 8))
	TreeRules.master(hero, ContentDB.abilities[&"F07"])
	hero.cooldowns = Cooldowns.new()
	sim.cast(hero, ContentDB.abilities[&"F07"], null, _a(8, 6))
	var marks := view._tile_marks()
	assert_true(marks.has(_t(8, 8)), "burning ground")
	var outlined := session.telegraphs().filter(func(h): return h.get("outline", PackedVector2Array()).size() > 2)
	assert_eq(outlined.size(), 1, "the fireball's circle is telegraphed")
	assert_true(_inside(outlined[0].outline, _a(8, 6)))


func test_an_aimed_bar_ability_pressed_while_dead_does_nothing() -> void:
	ContentDB.rules.timing_bars_enabled = true
	hero.die()
	input.use_slot_ability_for_test(ContentDB.abilities[&"F03"], &"action_slot_1")
	assert_false(input.is_aiming(), "no aiming while dead (and no error)")
	assert_true(client.aim.is_empty())


## Item 3 (2026-11-15): mouse-aimed abilities go toward the cursor every time.
func _learn(item: StringName) -> void:
	hero.bag.add(ContentDB.items[item])
	TreeRules.learn_from_bag(hero, hero.bag.index_of(ContentDB.items[item]))


func test_slash_swings_at_the_cursor_even_with_a_target_selected() -> void:
	wolf.move.place(_t(6, 8)) # right beside the hero, to the east, and targeted
	client.target_id = wolf.id
	var hp := wolf.hp
	_point_at(_a(5, 5)) # straight up the grid: away from the wolf
	# With its timing bar (as in play): the bar starts on the key press, and the
	# swing used to lock onto the targeted enemy until the mouse moved.
	ContentDB.rules.timing_bars_enabled = true
	input.use_slot_ability_for_test(ContentDB.abilities[&"S01"], &"action_slot_1")
	await wait_physics_frames(4)
	assert_eq(hero.casting.get("kind", ""), "timing")
	if hero.casting.is_empty():
		return
	var zone: Vector2 = hero.casting.ability.timing_bar.inputs()[0].zone
	while session.render_time() - float(hero.casting.start) < zone.x + zone.y / 2.0:
		await wait_physics_frames(1)
	input.press_timing_bar()
	await wait_physics_frames(3)
	assert_gt(hero.cooldowns.ability_remaining(&"S01", session.now()), 0.0, "it swung")
	assert_eq(wolf.hp, hp, "toward the cursor, so the targeted wolf beside it isn't hit")


func test_slash_on_a_timing_bar_swings_where_the_cursor_is_at_the_last_press() -> void:
	ContentDB.rules.timing_bars_enabled = true
	wolf.move.place(_t(4, 8)) # right beside the hero, to its grid −x
	var hp := wolf.hp
	_point_at(_a(5, 11)) # down the grid when the key is pressed: away from the wolf
	input.use_slot_ability_for_test(ContentDB.abilities[&"S01"], &"action_slot_1")
	await wait_physics_frames(4)
	assert_eq(hero.casting.get("kind", ""), "timing", "the bar runs")
	if hero.casting.is_empty():
		return
	_point_at(_a(3, 8)) # then the cursor moves onto the wolf before the press
	var bar: TimingBarDef = hero.casting.ability.timing_bar
	var zone: Vector2 = bar.inputs()[0].zone # start, length
	while session.render_time() - float(hero.casting.start) < zone.x + zone.y / 2.0:
		await wait_physics_frames(1)
	input.press_timing_bar()
	await wait_physics_frames(3)
	assert_true(hero.casting.is_empty(), "the swing went off")
	assert_lt(wolf.hp, hp, "it swung where the cursor was at the press, and hit the wolf")


func test_lunge_dashes_toward_the_cursor_with_a_target_elsewhere() -> void:
	hero.bag.add(ContentDB.items[&"travelers_longsword"])
	hero.equip_from_bag(hero.bag.index_of(ContentDB.items[&"travelers_longsword"]))
	assert_not_null(hero.find_ability(&"S04"), "Lunge from the longsword in hand")
	client.target_id = wolf.id # to the east
	_point_at(_a(5, 4)) # north (grid −y)
	var start := hero.move.pos
	input.use_slot_ability_for_test(ContentDB.abilities[&"S04"], &"action_slot_1")
	input.fire_aimed()
	await wait_physics_frames(15)
	var moved := hero.move.pos - start
	assert_gt(moved.length(), 0.5, "it dashed")
	assert_almost_eq(rad_to_deg(moved.angle()), -90.0, 10.0, "toward the cursor (north), not the wolf (east)")


func test_off_the_map_the_aim_still_points_toward_the_cursor() -> void:
	# A cursor beyond the map's edge (no tile under it) still gives a direction
	# toward it, not "straight ahead".
	hero.face(Vector2i.RIGHT)
	input.mouse_override = Iso.to_screen(Vector2(-40, -40), 0.0) # far off the map, up-left
	var p := input.mouse_point(ContentDB.abilities[&"S01"])
	var d := (p - hero.move.pos).normalized()
	assert_lt(d.x, -0.5)
	assert_lt(d.y, -0.5)


# --- Controller (2026-11-22) ---------------------------------------------------

func test_a_controller_auto_locks_on_the_enemy_ahead() -> void:
	InputDevice.set_kind(InputDevice.Kind.GAMEPAD)
	client.pad_aim = ClientState.PadAim.AUTO_LOCK
	var dart: AbilityDef = ContentDB.abilities[&"F03"]
	hero.move.place(_t(4, 8))
	assert_eq(input.locked_enemy(hero, 0.0), wolf, "the wolf, four tiles ahead")
	assert_almost_eq(input.pad_point(dart).distance_to(wolf.move.pos), 0.0, 0.01, "aims at it")
	assert_null(input.locked_enemy(hero, PI), "facing away and out of close range: nothing")
	client.pad_aim = ClientState.PadAim.TWIN_STICK
	var p := input.pad_point(dart)
	assert_almost_eq(p.distance_to(hero.move.pos), dart.hitbox.reach, 0.01, "twin-stick: straight ahead at full reach")
	InputDevice.set_kind(InputDevice.Kind.KEYBOARD)


func test_manual_aim_abilities_ignore_the_lock() -> void:
	InputDevice.set_kind(InputDevice.Kind.GAMEPAD)
	client.pad_aim = ClientState.PadAim.AUTO_LOCK
	var fireball: AbilityDef = ContentDB.abilities[&"F07"]
	assert_true(fireball.manual_aim, "Fireball is Manual Aim in the sheet")
	input._pad_aim_angle = PI / 2.0 # the right stick last pointed grid-down
	var p := input.pad_point(fireball)
	assert_gt(p.y - hero.move.pos.y, 0.5, "goes where the stick pointed, not at the wolf")
	assert_false(ContentDB.abilities[&"F03"].manual_aim)
	InputDevice.set_kind(InputDevice.Kind.KEYBOARD)


func test_a_targeted_ability_with_nothing_targeted_picks_the_foe_at_the_cursor() -> void:
	client.target_id = -1
	input.mouse_override = Iso.to_screen(wolf.move.pos, session.grid().height_at(wolf.tile()))
	var gust := ContentDB.abilities.get(&"A02") as AbilityDef
	assert_eq(input._target_for(hero, gust), wolf)


func test_the_starting_kits_go_to_their_slots() -> void:
	# Earth: Rock Throw (ranged) on Y, Stone Skin (defense) on A; Fire's Flame Dash
	# on A; a weapon's art on X.
	assert_eq(Hud.wheel_slot_of(&"E01"), 1)
	assert_eq(Hud.wheel_slot_of(&"E02"), 2)
	assert_eq(Hud.wheel_slot_of(&"F05"), 2)
	assert_eq(Hud.wheel_slot_of(&"A03"), 2)
	assert_eq(Hud.wheel_slot_of(&"F03"), 1)
	assert_eq(Hud.wheel_slot_of(&"S01"), 0)
	assert_eq(Hud.wheel_slot_of(&"B01"), 0, "Quick Shot is ranged but it's the weapon")
	assert_eq(Hud.wheel_slot_of(&"F01"), -1, "Fire Punch: the rest")