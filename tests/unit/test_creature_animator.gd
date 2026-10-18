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


func test_run_plays_one_cycle_per_tile() -> void:
	wolf.move.begin(Vector2i(3, 1), 5.0, 0.8)
	assert_eq(anim.pick(wolf, art, 5.0).frame, 0)
	assert_eq(anim.pick(wolf, art, 5.0 + 0.4).frame, 4, "halfway across: frame 4 of 8")
	assert_eq(anim.pick(wolf, art, 5.0 + 0.79).frame, 7)
	assert_eq(anim.pick(wolf, art, 5.0).anim, "run")


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
