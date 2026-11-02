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
	client = ClientState.new()
	InputActions.apply_action_bar_keys(client.action_bar)
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


func test_hold_to_aim_and_release_to_cast() -> void:
	client.target_id = wolf.id
	input.use_slot_ability_for_test(ContentDB.abilities[&"F03"], &"action_slot_1")
	assert_true(input.is_aiming())
	assert_false(client.aim.is_empty())
	assert_eq(client.aim.point, Vector2(wolf.tile()), "aims at the target until the mouse moves")
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
			_a(14, 8), null, session.now())
	assert_eq(p.result, AbilityResolver.Result.OK, "a circle aimed too far lands at the edge of its range")
	assert_true(_inside(p.outline, _a(10, 8)), "5 tiles out")
	assert_false(_inside(p.outline, _a(14, 8)))
	# A grid ability (terrain) still refuses an aim out of range.
	TreeRules.master(hero, ContentDB.abilities[&"E03"])
	p = AimPreview.preview(session.grid(), session.rules(), session.actors(), hero, ContentDB.abilities[&"E03"],
			_a(14, 8), null, session.now())
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
