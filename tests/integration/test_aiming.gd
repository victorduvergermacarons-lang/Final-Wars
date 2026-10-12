extends GutTest
## Aiming (Milestone 3 §3): hold an aimed ability's key, see the exact tiles it
## would affect, release to cast. Telegraphs and previews on the client copy.

var session: LocalSession
var client: ClientState
var view: WorldView
var input: PlayerInput
var hero: Hero
var wolf: Enemy


func before_each() -> void:
	InputActions.ensure_registered()
	session = LocalSession.new()
	add_child(session)
	session.start(ContentDB.zones.values(), &"town", ContentDB.rules,
			CharacterData.new_character("Aimer", ContentDB.heroes[&"adventurer"]))
	hero = session.local_hero()
	client = ClientState.new()
	InputActions.apply_action_bar_keys(client.action_bar)
	view = WorldView.new()
	add_child(view)
	view.setup(session, client, ContentDB.zones[&"town"])
	input = PlayerInput.new()
	add_child(input)
	input.setup(session, client, view)
	hero.move.place(Vector2i(5, 8))
	hero.face(Vector2i.RIGHT)
	wolf = session.zone_sim().add_enemy(ContentDB.enemies[&"wolf"], Vector2i(8, 8))
	hero.bag.add(ContentDB.items[&"spark_scroll"])
	TreeRules.learn_from_bag(hero, hero.bag.index_of(ContentDB.items[&"spark_scroll"]))


func after_each() -> void:
	input.free()
	view.free()
	session.free()


func _preview(id: StringName, aim: Vector2) -> Array:
	var p := AimPreview.preview(session.grid(), session.rules(), session.actors(), hero, ContentDB.abilities[id],
			aim, null, session.now())
	return p.tiles


func test_screen_to_tile_round_trip() -> void:
	for h in [0, 1, 3]:
		var t := Vector2(7, 4)
		var back := Iso.from_screen(Iso.to_screen(t, h), h)
		assert_almost_eq(back.x, t.x, 0.001)
		assert_almost_eq(back.y, t.y, 0.001)
	var tile := Vector2i(6, 9)
	var screen := Iso.to_screen(Vector2(tile), session.grid().height_at(tile))
	assert_eq(view.tile_at(screen), tile, "the tile under the cursor")


func test_aimed_abilities_need_no_target() -> void:
	var dart: AbilityDef = ContentDB.abilities[&"F03"]
	assert_true(AimPreview.is_aimed(dart))
	assert_eq(Targeting.pick(hero, dart, null).error, "")
	assert_eq(Targeting.pick(hero, ContentDB.abilities[&"F04"], null).target, hero.id, "self abilities")


func test_previews_show_the_exact_tiles() -> void:
	assert_eq(_preview(&"F03", Vector2(12, 8)), [Vector2i(6, 8), Vector2i(7, 8), Vector2i(8, 8)],
			"a dart stops at the first enemy")
	assert_eq(_preview(&"F06", Vector2(9, 12)), [Vector2i(6, 9), Vector2i(7, 10), Vector2i(8, 11)],
			"the whip snaps to 8 directions")
	assert_eq(_preview(&"F07", Vector2(8, 8)).size(), 9, "a 3x3 blast")
	var wall := _preview(&"E05", Vector2(5, 11))
	assert_eq(wall, [Vector2i(4, 11), Vector2i(5, 11), Vector2i(6, 11)], "a wall across the aim")
	assert_eq(hero.facing, Vector2i.RIGHT, "previewing doesn't turn the hero")
	assert_eq(_preview(&"F05", Vector2(5, 11)), [Vector2i(5, 9), Vector2i(5, 10), Vector2i(5, 11)], "the dash path")


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


func test_out_of_range_ground_aim_is_shown_as_invalid() -> void:
	hero.bag.add(ContentDB.items[&"scroll_of_the_fireball"])
	TreeRules.master(hero, ContentDB.abilities[&"F07"])
	var p := AimPreview.preview(session.grid(), session.rules(), session.actors(), hero, ContentDB.abilities[&"F07"],
			Vector2(14, 8), null, session.now())
	assert_eq(p.result, AbilityResolver.Result.OUT_OF_RANGE)


func test_telegraphs_and_zones_reach_the_view() -> void:
	var sim := session.zone_sim()
	TreeRules.master(hero, ContentDB.abilities[&"F08"])
	sim.cast(hero, ContentDB.abilities[&"F08"], null, Vector2(8, 8))
	TreeRules.master(hero, ContentDB.abilities[&"F07"])
	hero.cooldowns = Cooldowns.new()
	sim.cast(hero, ContentDB.abilities[&"F07"], null, Vector2(8, 5))
	var marks := view._tile_marks()
	assert_true(marks.has(Vector2i(8, 8)), "burning ground")
	assert_true(marks.has(Vector2i(8, 5)), "fireball telegraph")
