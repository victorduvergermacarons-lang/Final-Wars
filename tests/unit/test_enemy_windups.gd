extends GutTest
## Faster enemy attacks (2026-11-17): wind-ups cut by up to 40%, never below the
## warning a dodgeable attack needs (a tile at walking speed plus the reaction
## time; CastResolver.dodge_warnings) nor 0.2 s for the quick bites; the boss
## telegraphs that are the whole point keep theirs; art-timed attacks still land
## on their hit frame.

const QUICK_FLOOR := 0.2


func test_no_dodgeable_attack_is_too_quick_to_dodge() -> void:
	assert_eq(Array(CastResolver.dodge_warnings(ContentDB.abilities.values(), ContentDB.rules)), [])


func test_quick_bites_keep_a_short_warning() -> void:
	for id in [&"wolf_bite", &"hound_bite", &"quick_slash", &"boar_gore", &"talon_rake"]:
		assert_gte(ContentDB.abilities[id].windup_seconds, QUICK_FLOOR - 0.0001, str(id))


func test_boss_telegraphs_keep_their_warning() -> void:
	assert_eq(ContentDB.abilities[&"foreman_slam"].telegraph_seconds, 1.0)
	assert_eq(ContentDB.abilities[&"foreman_charge"].windup_seconds, 1.1)
	assert_eq(ContentDB.abilities[&"sunfire_breath"].windup_seconds, 0.8)
	assert_eq(ContentDB.abilities[&"searing_dive"].windup_seconds, 1.0)


func test_art_timed_attacks_land_on_their_hit_frame() -> void:
	for e: EnemyDef in ContentDB.enemies.values():
		if e.art == null:
			continue
		for a in e.abilities:
			var w := e.art.windup_for(a.id)
			if w >= 0.0:
				assert_almost_eq(a.windup_seconds, w, 0.0001, "%s %s" % [e.id, a.id])
