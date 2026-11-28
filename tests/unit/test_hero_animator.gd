extends GutTest
## Which frame a hero shows (CreatureAnimator.pick_hero), from the host's times in
## Hero.anim: death then lying down, downed while stunned, revived, the weapon
## sets only with that weapon in hand, cast otherwise, hit, walk and idle; and the
## art itself (8 facings, 9 frames each, one feet point); the walk follows the
## distance walked on screen.

var art: CreatureArtDef
var hero: Hero
var animator: CreatureAnimator
const T := 100.0


func before_each() -> void:
	art = ContentDB.heroes[&"adventurer"].art
	hero = Hero.from_def(1, ContentDB.heroes[&"adventurer"])
	animator = CreatureAnimator.new()


func _pick(t := T) -> Dictionary:
	return animator.pick_hero(hero, art, t)


func test_every_sheet_has_eight_facings_of_nine_frames() -> void:
	for anim in ["idle", "run", "cast", "hit", "death", "downed", "revived",
			"sword_slash", "sword_lunge", "bow_quick_shot", "bow_aimed_shot",
			"earth_root", "earth_hold", "earth_punch", "fire_punch", "fire_kick", "water_heal",
			"water_whip", "air_palm", "air_gust", "stone_shatter"]:
		var tex: Texture2D = art.sheets.get(anim)
		assert_not_null(tex, anim)
		if tex != null:
			assert_eq(Vector2i(tex.get_width(), tex.get_height()), Vector2i(9 * 48, 8 * 48), anim)
	assert_eq(art.rows, PackedStringArray(["sw", "se", "nw", "ne", "s", "e", "n", "w"]))
	assert_eq(art.feet, Vector2(24, 38), "the measured feet point")


func test_idle_and_walk() -> void:
	assert_eq(_pick().anim, "idle")
	hero.move.vel = Vector2(3, 0)
	hero.move.pos += Vector2(0.5, 0)
	hero.move.odometer = 0.5
	hero.move.screen_odometer = 5.0 * art.run_px_per_frame["se"] + 0.01
	hero.face(Vector2i.RIGHT)
	if hero.move.is_moving(T):
		assert_eq(_pick().anim, "run")
		assert_eq(_pick().frame, 5, "a frame per run_px_per_frame art px on screen")


## The feet keep pace with the ground on screen: the same ground distance plays
## half the frames going up the screen as going across it (iso halves heights),
## and a slower walk (a slow, Earth Armor, Haste) plays proportionally.
func test_the_walk_follows_the_screen_distance() -> void:
	var across := MoveState.screen_length(Vector2(1, -1).normalized()) # one tile across the screen
	var up := MoveState.screen_length(Vector2(-1, -1).normalized()) # one tile up it
	assert_almost_eq(across, 22.63, 0.01)
	assert_almost_eq(up, 11.31, 0.01)
	var frames_e: float = across / art.run_px_per_frame["e"]
	var frames_n: float = up / art.run_px_per_frame["n"]
	assert_lt(frames_n, frames_e, "fewer frames per tile walking up the screen")
	var world := WorldSim.new(ContentDB.zones[&"town"], ContentDB.rules, 1)
	var h := world.add_hero(ContentDB.heroes[&"adventurer"])
	h.move.place(Vector2i(6, 7))
	world.step()
	world.submit(h.id, {"type": "move", "dir": Vector2i(1, 0), "face": 0.0})
	world.advance(0.5)
	var full := h.move.screen_odometer
	assert_almost_eq(full / h.move.odometer, across, 0.5, "screen distance tracks the walk")
	# Half the speed (a slow, Earth Armor): half the screen distance in the same time,
	# so half the frames: the cadence follows the speed by itself.
	var o0 := h.move.screen_odometer
	h.move.vel = Vector2.ZERO
	world.submit(h.id, {"type": "move", "dir": Vector2i.ZERO, "face": 0.0})
	world.advance(0.3)
	assert_almost_eq(h.move.screen_odometer - o0, 0.0, 3.0, "stopping stops the cycle")
	assert_eq(MoveState.screen_length(Vector2.ZERO), 0.0)


## Eight facings: grid axes are the diagonal views, grid diagonals the straight
## ones (screen up is grid (-1, -1)).
func test_the_facing_angle_picks_one_of_eight_rows() -> void:
	var want := {0.0: "se", 45.0: "s", 90.0: "sw", 135.0: "w", 180.0: "nw", -135.0: "n", -90.0: "ne", -45.0: "e",
			20.0: "se", 25.0: "s"}
	for deg in want:
		hero.face_angle(deg_to_rad(deg))
		assert_eq(_pick().dir, want[deg], "%s°" % deg)


func test_grid_facings_pick_the_diagonal_rows() -> void:
	for f in {Vector2i.DOWN: "sw", Vector2i.RIGHT: "se", Vector2i.LEFT: "nw", Vector2i.UP: "ne"}.keys():
		hero.face(f)
		assert_eq(_pick().dir, {Vector2i.DOWN: "sw", Vector2i.RIGHT: "se", Vector2i.LEFT: "nw", Vector2i.UP: "ne"}[f])


func test_element_spells_and_hammer_arts_cast() -> void:
	hero.anim.act = &"F03" # Fire Dart: no animation of its own yet
	hero.anim.act_at = T - 0.1
	assert_eq(_pick().anim, "cast")
	assert_eq(_pick().frame, 1, "18 fps")
	hero.anim.act = &"H01"
	assert_eq(_pick().anim, "cast", "no hammer art yet: the plain cast")
	hero.anim.act = &""
	assert_eq(_pick().anim, "cast", "a potion")
	assert_eq(_pick(T + 1.0).anim, "idle", "over after its 9 frames")


func test_weapon_arts_need_their_weapon_in_hand() -> void:
	hero.anim.act = &"S01"
	hero.anim.act_at = T
	hero.set_equipped_raw({})
	assert_eq(_pick().anim, "cast", "no sword in hand: the plain body")
	hero.wear(ContentDB.items[&"travelers_longsword"])
	assert_eq(_pick().anim, "sword_slash")
	hero.anim.act = &"S04"
	assert_eq(_pick().anim, "sword_lunge")
	hero.wear(ContentDB.items[&"hunters_shortbow"])
	hero.anim.act = &"B01"
	assert_eq(_pick().anim, "bow_quick_shot")
	hero.anim.act = &"B02"
	assert_eq(_pick().anim, "bow_aimed_shot")
	hero.anim.act = &"S01"
	assert_eq(_pick().anim, "cast", "a bow in hand now")


func test_hit_plays_once() -> void:
	hero.anim.hit = T - 0.2
	assert_eq(_pick().anim, "hit")
	assert_eq(_pick().frame, 3)
	assert_eq(_pick(T + 1.0).anim, "idle")


func test_death_then_lying_down_until_up_again() -> void:
	hero.alive = false
	hero.anim.died = T - 0.25
	var p := _pick()
	assert_eq([p.anim, p.frame], ["death", 3])
	p = _pick(T + 5.0)
	assert_eq([p.anim, p.frame], ["downed", 8], "lying in downed's last frame")
	hero.anim.died = Hero.NEVER # joined after the death: lying already
	assert_eq(_pick().anim, "downed")
	hero.alive = true
	hero.anim.up = T - 0.1
	assert_eq(_pick().anim, "revived")
	assert_eq(_pick(T + 2.0).anim, "idle")


func test_stunned_falls_and_lies_until_it_ends() -> void:
	hero.buffs.apply(ContentDB.buffs[&"searing_dive_stun"], T - 0.2)
	hero.anim.down = T - 0.2
	var p := _pick()
	assert_eq([p.anim, p.frame], ["downed", 3])
	p = _pick(T + 0.9)
	assert_eq([p.anim, p.frame], ["downed", 8], "held")


## 2026-11-19: the drawn west and north-west getting-hit rows looked wrong; they are
## the east and north-east rows mirrored, frame for frame, about the feet.
func test_west_and_north_west_hits_are_east_and_north_east_mirrored() -> void:
	hero.anim.hit = T - 0.2
	# Grid-space angles: screen west is 3/4 pi, north-west pi (direction_for_angle).
	var angle := {"w": 3.0 * PI / 4.0, "nw": PI, "e": -PI / 4.0, "ne": -PI / 2.0}
	for pair in [[angle.w, "w", "e"], [angle.nw, "nw", "ne"]]:
		hero.facing_angle = pair[0]
		assert_eq(art.direction_for_angle(hero.facing_angle, hero.facing), pair[1])
		var p := _pick()
		assert_eq(p.anim, "hit")
		assert_eq(p.dir, pair[2], "%s shows the %s row" % [pair[1], pair[2]])
		assert_true(p.get("flip", false), "mirrored")
		hero.facing_angle = angle[pair[2]]
		var src := _pick()
		assert_eq(src.dir, pair[2])
		assert_false(src.get("flip", false), "the source row is drawn as it is")
		assert_eq(p.frame, src.frame, "same frame at the same moment: same timing")
	hero.anim.hit = Hero.NEVER
	hero.facing_angle = angle.w
	assert_false(_pick().get("flip", false), "only the hit is mirrored (west idle is drawn)")
	assert_eq(art.feet.x, art.frame_size.x / 2.0, "the feet sit mid-frame, so mirroring keeps them in place")


# --- Ability animations (2026-11-21) ----------------------------------------------

func test_an_element_ability_plays_from_its_strike_frame() -> void:
	hero.anim.act = &"F01" # Fire Punch: instant, the punch lands as it shows
	hero.anim.act_at = T
	assert_eq(_pick().anim, "fire_punch")
	assert_eq(_pick().frame, art.ability_anim(&"F01").strike, "starts on its strike frame")
	assert_eq(_pick(T + 2.0 / 24.0 + 0.001).frame, art.ability_anim(&"F01").strike + 2, "24 fps")
	assert_eq(_pick(T + 1.0).anim, "idle", "then it's over")


func test_a_bar_plays_the_frames_before_the_strike_and_holds() -> void:
	hero.casting = {"ability": ContentDB.abilities[&"F02"], "kind": "timing", "start": T, "end": T + 1.2}
	assert_eq(_pick(T + 0.001).anim, "fire_kick")
	assert_eq(_pick(T + 0.001).frame, 0)
	var strike: int = art.ability_anim(&"F02").strike
	assert_eq(_pick(T + 1.0).frame, strike - 1, "held just before the kick")
	hero.casting = {}
	hero.anim.act = &"F02"
	hero.anim.act_at = T + 1.0
	assert_eq(_pick(T + 1.001).frame, strike, "the kick lands on its strike frame")


func test_rock_throw_roots_holds_then_punches_from_the_start() -> void:
	hero.casting = {"ability": ContentDB.abilities[&"E01"], "kind": "timing", "start": T, "end": T + 3.0}
	assert_eq(_pick(T + 0.1).anim, "earth_root")
	var rooted := T + art.duration("earth_root") + 0.01
	assert_eq(_pick(rooted).anim, "earth_hold", "then the hold, looping")
	assert_eq(_pick(rooted + art.duration("earth_hold")).anim, "earth_hold")
	hero.casting = {}
	hero.anim.act = &"E01"
	hero.anim.act_at = T + 2.0
	assert_eq(_pick(T + 2.001).anim, "earth_punch")
	assert_eq(_pick(T + 2.001).frame, 0, "from the start: the rock leaves on the strike frame")
	assert_almost_eq(art.strike_seconds(&"E01"), 3.0 / 20.0, 0.001)
	assert_almost_eq(ContentDB.abilities[&"E01"].release_delay_seconds, art.strike_seconds(&"E01"), 0.001,
			"the rock flies on earth_punch's strike frame")


func test_stone_skin_roots_then_shatters_when_it_ends() -> void:
	hero.anim.act = &"E02"
	hero.anim.act_at = T
	assert_eq(_pick(T + 0.01).anim, "earth_root")
	hero.anim.act = &""
	hero.anim.buff_end = T + 5.0
	hero.anim.buff_end_anim = "stone_shatter"
	assert_eq(_pick(T + 5.01).anim, "stone_shatter")
	assert_eq(_pick(T + 5.0 + art.duration("stone_shatter") + 0.01).anim, "idle", "then the hero, without stone")
	assert_true(art.looks.has(&"stone"), "the grey-stone look")
	assert_eq(ContentDB.buffs[&"stone_skin"].look, &"stone_25", "a quarter, like Earth stance 1")


func test_the_host_records_when_stone_skin_ends() -> void:
	var world := WorldSim.new(ContentDB.zones[&"town"], ContentDB.rules, 1)
	var h := world.add_hero(ContentDB.heroes[&"adventurer"])
	h.buffs.apply(ContentDB.buffs[&"stone_skin"], world.now, 0.0, h.id)
	world.step()
	assert_eq(float(h.anim.buff_end), Hero.NEVER)
	world.advance(ContentDB.buffs[&"stone_skin"].duration_seconds + 0.1)
	assert_gt(float(h.anim.buff_end), 0.0, "noted when it ended")
	assert_eq(h.anim.buff_end_anim, "stone_shatter")
