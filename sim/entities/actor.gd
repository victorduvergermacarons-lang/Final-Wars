class_name Actor
extends RefCounted
## Common state for anything that fights: heroes and enemies.
## `stats` are the effective stats before buffs (base + growth + gear for heroes);
## whoever owns the actor keeps them up to date.

enum Team {
	HEROES,
	ENEMIES,
	NEUTRAL, ## NPCs: nobody's friend or foe.
}

var id: int = 0
var team: Team = Team.HEROES
var display_name: String = ""
var stats: StatBlock = StatBlock.new()
var hp: float = 0.0
var mana: float = 0.0
var alive: bool = true
var move := MoveState.new()
## Which way the actor faces: one of GridModel.DIRECTIONS. Steps turn the actor;
## FRONT and LINE abilities aim this way.
var facing := Vector2i.DOWN
var cooldowns := Cooldowns.new()
## Light characters are knocked back and pulled 1 tile further, heavy ones 1 less.
var weight: Weight.Id = Weight.Id.MEDIUM
var buffs := ActiveBuffs.new()
## Enemies only: who they want to hit. Null for heroes.
var threat: ThreatTable
## Sim time until which this actor counts as in combat (refreshed by WorldSim).
var combat_until: float = -1.0
## Leashing enemies can't be targeted by hostile abilities.
var evading: bool = false


func _init(p_id: int = 0, p_team: Team = Team.HEROES, p_stats: StatBlock = null) -> void:
	id = p_id
	team = p_team
	if p_stats != null:
		stats = p_stats
	hp = stats.hp
	mana = stats.mana
	if team == Team.ENEMIES:
		threat = ThreatTable.new()


func tile() -> Vector2i:
	return move.to_tile


## Stats with active buffs applied.
## The ability being cast, wound up or channelled ({} when idle):
## {"ability", "target", "aim", "kind": "cast"|"windup"|"channel", "start", "end",
## "next_tick", "bonus"}. WorldSim drives it.
var casting := {}


func current_stats(now: float) -> StatBlock:
	return buffs.modify(stats, now)


## Turns to face `dir` if it is one of the four grid directions.
func face(dir: Vector2i) -> bool:
	if not GridModel.DIRECTIONS.has(dir):
		return false
	facing = dir
	return true


## The tile directly in front of the actor.
func front_tile() -> Vector2i:
	return tile() + facing


## Seconds before the next step while in combat.
func combat_step_cooldown(rules: CombatRules, now: float) -> float:
	return StatCalc.combat_step_cooldown(current_stats(now).speed, rules)


func in_combat(now: float) -> bool:
	return alive and now < combat_until


func is_hostile_to(other: Actor) -> bool:
	return team != other.team and team != Team.NEUTRAL and other.team != Team.NEUTRAL


## Same side (heroes with heroes, enemies with enemies); neutral is no one's ally.
func is_ally_of(other: Actor) -> bool:
	return team == other.team and team != Team.NEUTRAL


func die() -> void:
	alive = false
	hp = 0.0
	combat_until = -1.0
	buffs.clear()
