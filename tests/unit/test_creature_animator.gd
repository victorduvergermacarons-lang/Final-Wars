extends GutTest
## Which wolf frame shows, from the replicated state only.

var world: WorldSim
var wolf: Enemy
var art: CreatureArtDef
var anim: CreatureAnimator


func before_each() -> void:
	var zone := ZoneDef.new()
	zone.id = &"arena"
	zone.height_rows = PackedStringArray(["00000", "00000", "00000"])
	zone.walk_rows = PackedStringArray([".....", ".....", "....."])
	zone.graveyards = [Vector2i(0, 0)]
	zone.hero_spawns = [Vector2i(0, 0)]
	world = WorldSim.new(zone, ContentDB.rules, 1)
	var def: EnemyDef = ContentDB.enemies[&"wolf"].duplicate()
	def.aggro_radius = 0
	wolf = world.add_enemy(def, Vector2i(2, 1))
	art = def.art
	anim = CreatureAnimator.new()


func test_idle_loops_at_its_frame_rate() -> void:
	var a := anim.pick(wolf, art, 10.0)
	assert_eq(a.anim, "idle")
	var b := anim.pick(wolf, art, 10.0 + 1.0 / art.anim_fps("idle"))
	assert_eq(b.frame, (a.frame + 1) % 4, "one frame later")


func test_facing_picks_the_row() -> void:
	wolf.face(Vector2i(0, -1))
	assert_eq(anim.pick(wolf, art, 1.0).dir, "ne")
	wolf.face(Vector2i(-1, 0))
	assert_eq(anim.pick(wolf, art, 1.0).dir, "nw")


func test_run_cycle_spans_two_tiles_so_the_paws_keep_pace() -> void:
	wolf.move.place(Vector2i(2, 2))
	wolf.move.begin(Vector2i(3, 2), 5.0, 0.8)
	assert_eq(anim.pick(wolf, art, 5.0).anim, "run")
	assert_eq(anim.pick(wolf, art, 5.0).frame, 0)
	assert_eq(anim.pick(wolf, art, 5.0 + 0.4).frame, 2, "halfway across: 4 frames per tile")
	assert_eq(anim.pick(wolf, art, 5.0 + 0.79).frame, 3)
	# The next tile plays the other half of the cycle, whichever way it goes.
	for to in [Vector2i(4, 2), Vector2i(3, 3), Vector2i(2, 2), Vector2i(3, 1)]:
		wolf.move.place(Vector2i(3, 2))
		wolf.move.begin(to, 6.0, 0.8)
		assert_eq(anim.pick(wolf, art, 6.0).frame, 4, "step to %s carries on the stride" % to)
		assert_eq(anim.pick(wolf, art, 6.79).frame, 7)


func _start_bite(at: float) -> void:
	var bite: AbilityDef = ContentDB.abilities[&"wolf_bite"]
	wolf.casting = {"ability": bite, "kind": "windup", "start": at, "end": at + bite.windup_seconds}


func test_bite_plays_from_the_wind_up_and_lands_on_frame_12() -> void:
	_start_bite(2.0)
	assert_eq(anim.pick(wolf, art, 2.0).anim, "bite")
	assert_eq(anim.pick(wolf, art, 2.0).frame, 0)
	var hit := anim.pick(wolf, art, 2.0 + 0.4)
	assert_eq(hit.frame, 12, "the wind-up ends (damage) on the jaw frame")


func test_bite_recovery_plays_after_the_wind_up_ends() -> void:
	_start_bite(2.0)
	anim.pick(wolf, art, 2.3)
	wolf.casting = {} # the host resolved it at 2.4
	var after := anim.pick(wolf, art, 2.45)
	assert_eq(after.anim, "bite")
	assert_eq(after.frame, 13)
	assert_eq(anim.pick(wolf, art, 2.6).anim, "idle", "15 frames done")


func test_cancelled_bite_stops_at_once() -> void:
	_start_bite(2.0)
	anim.pick(wolf, art, 2.1)
	wolf.casting = {} # interrupted at 2.1
	assert_eq(anim.pick(wolf, art, 2.12).anim, "idle")


func test_dead_creature_shows_nothing_yet() -> void:
	wolf.alive = false
	assert_true(anim.pick(wolf, art, 1.0).is_empty())


func test_wolf_glides_over_its_whole_step_in_combat() -> void:
	wolf.state = Enemy.State.COMBAT
	assert_eq(world.try_step(wolf, Vector2i(3, 1)), "")
	assert_almost_eq(wolf.move.duration, wolf.def.combat_step_seconds, 0.001)


func test_wolf_stays_put_during_the_bite_and_its_recovery() -> void:
	var hd := HeroDef.new()
	hd.base_stats = StatBlock.make({Stat.Id.HP: 5000})
	var hero := world.add_hero(hd)
	hero.move.place(Vector2i(2, 2))
	wolf.def.aggro_radius = 4
	wolf.face(Vector2i(0, 1))
	var events := []
	var bitten_at := -1.0
	var start_tile := wolf.tile()
	for i in 40:
		events = world.step()
		if events.any(func(e): return e.type == "damage" and e.target == hero.id):
			bitten_at = world.now
			break
		assert_eq(wolf.tile(), start_tile, "doesn't move while winding up")
	assert_gt(bitten_at, 0.0, "it bit")
	assert_almost_eq(wolf.busy_until, bitten_at + 2.0 / 30.0, 0.001, "busy for 2 recovery frames")


func test_death_plays_once_then_the_corpse_lies_and_fades() -> void:
	wolf.alive = false
	wolf.died_at = 10.0
	var start := anim.pick(wolf, art, 10.0)
	assert_eq(start.anim, "death")
	assert_eq(start.frame, 0)
	var dead_still := anim.pick(wolf, art, 10.0 + art.duration("death") + 1.0)
	assert_eq(dead_still.frame, 11, "holds the last frame")
	assert_eq(dead_still.alpha, 1.0, "the corpse lies there")
	var fading := anim.pick(wolf, art, 10.0 + art.duration("death") + art.corpse_seconds + art.fade_seconds * 0.5)
	assert_almost_eq(fading.alpha, 0.5, 0.01, "halfway through the fade")
	assert_true(anim.pick(wolf, art, 10.0 + art.corpse_total() + 0.01).is_empty(), "gone")


func test_death_time_is_recorded_and_spawned_corpses_go_after_fading() -> void:
	var def: EnemyDef = ContentDB.enemies[&"wolf"].duplicate()
	def.aggro_radius = 0
	var temp := world.add_enemy(def, Vector2i(4, 2))
	temp.temporary = true
	var bolt := AbilityDef.new()
	bolt.id = &"t_kill"
	bolt.targeting = AbilityDef.TargetingMode.TARGETED
	bolt.max_range = 10
	bolt.on_gcd = false
	var dmg := AbilityEffect.new()
	dmg.base_amount = 9999
	dmg.can_crit = false
	bolt.effects = [dmg] as Array[AbilityEffect]
	var hd := HeroDef.new()
	hd.base_stats = StatBlock.make({Stat.Id.HP: 500})
	var hero := world.add_hero(hd)
	hero.move.place(Vector2i(4, 0))
	world.cast(hero, bolt, temp)
	assert_false(temp.alive)
	assert_almost_eq(temp.died_at, world.now, 0.001)
	world.advance(art.corpse_total() - 0.5)
	assert_not_null(world.get_actor(temp.id), "the corpse is still there")
	world.advance(1.0)
	assert_null(world.get_actor(temp.id), "removed once faded")
